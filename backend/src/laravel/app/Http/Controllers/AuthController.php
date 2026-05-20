<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use App\Services\ActivityLogService;
use App\Support\MediaUrlHelper;
use App\Support\UserPayload;

class AuthController extends Controller
{
    //
    public function register(Request $request)
    {
        $request->validate([
            'first_name' => 'required|string|max:255',
            'last_name' => 'required|string|max:255',
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => 'required|string|min:8',
            'accepted_terms' => 'required|accepted',
        ]);
        $user = User::create([
            'first_name' => $request->first_name,
            'last_name' => $request->last_name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => 'user',
        ]);

        $token = $user->createToken('auth-token')->plainTextToken;

        return response()->json([
            'message' => 'User created successfully',
            'user' => UserPayload::make($user),
            'token' => $token
        ], 201);
    }

    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|string|email|max:255',
            'password' => 'required|string|min:8',
        ]);
        $user = User::where('email', $request->email)->first();
        if (! $user || ! Hash::check($request->password, $user->password)) {
            ActivityLogService::log('auth', 'login_failed', 'Invalid credentials', $user?->id, null, ['email' => $request->email]);
            return response()->json(['message' => 'Invalid credentials'], 401);
        }

        // Intentional: deactivated users are reactivated automatically on successful login.
        if ($user->isDeactivatedAccount()) {
            $user->account_status = 'active';
            $user->save();

            ActivityLogService::log(
                'auth',
                'reactivate on login',
                'Account reactivated on login',
                $user->id
            );
        }

        if ($user->isSuspendedAccount()) {
            ActivityLogService::log('auth', 'login_failed', 'Account is suspended', $user?->id, null, ['email' => $request->email]);
            return response()->json(['message' => 'Account is suspended'], 403);
        }

        $token = $user->createToken('auth-token')->plainTextToken;

        ActivityLogService::log('auth', 'login_successful', 'Login successful', $user?->id, null, ['email' => $request->email]);
        return response()->json([
            'message' => 'Login successful',
            'user' => UserPayload::make($user),
            'token' => $token
        ], 200);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|string|email|max:255',
        ]);

        $email = strtolower(trim($request->email));
        $user = User::where('email', $email)->first();

        if ($user) {
            $code = (string) random_int(100000, 999999);
            Cache::put($this->passwordResetCodeCacheKey($email), Hash::make($code), now()->addMinutes(10));

            Mail::raw(
                "Your WellNest password reset code is: {$code}\n\nThis code expires in 10 minutes.",
                function ($message) use ($email) {
                    $message->to($email)->subject('Your WellNest password reset code');
                }
            );
        }

        return response()->json([
            'message' => 'If that email exists, a reset code has been sent.',
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|string|email|max:255',
            'code' => 'required|string|min:6|max:6',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $email = strtolower(trim($request->email));
        $cacheKey = $this->passwordResetCodeCacheKey($email);
        $storedHash = Cache::get($cacheKey);

        if (! $storedHash || ! Hash::check($request->code, $storedHash)) {
            return response()->json([
                'message' => 'The reset code is invalid or expired.',
            ], 422);
        }

        $user = User::where('email', $email)->first();
        if (! $user) {
            return response()->json([
                'message' => 'The reset code is invalid or expired.',
            ], 422);
        }

        $user->forceFill([
            'password' => Hash::make($request->password),
        ])->save();

        Cache::forget($cacheKey);

        return response()->json([
            'message' => 'Password reset successfully.',
        ]);
    }

    private function passwordResetCodeCacheKey(string $email): string
    {
        return 'password-reset-code:' . $email;
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();
        return response()->json(['message' => 'Logged out successfully'], 200);
    }

    public function deleteAccount(Request $request)
    {
        $user = $request->user();
        $userId = $user->id;
        ActivityLogService::log('auth', 'delete_account', 'Account deleted successfully', $userId);
        $user->delete();

        return response()->json(['message' => 'Account deleted successfully'], 200);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $request->validate([
            'first_name' => 'sometimes|string|max:255',
            'last_name' => 'sometimes|string|max:255',
            'email' => ['sometimes', 'string', 'email', 'max:255', Rule::unique('users', 'email')->ignore($request->user()->id)],
            'password' => 'sometimes|string|min:8',
        ]);

        $user = $request->user();
        $changes = [];

        if ($request->filled('first_name') && $request->first_name !== $user->first_name) {
            $changes[] = 'name';
            $user->first_name = $request->first_name;
        }
        if ($request->filled('last_name') && $request->last_name !== $user->last_name) {
            $changes[] = 'name';
            $user->last_name = $request->last_name;
        }
        if ($request->filled('email') && $request->email !== $user->email) {
            $changes[] = 'email';
            $user->email = $request->email;
        }
        if ($request->filled('password')) {
            $changes[] = 'password';
            $user->password = Hash::make($request->password);
        }

        $user->save();

        foreach (array_unique($changes) as $field) {
            ActivityLogService::log(
                'user_account_updates',
                "account_update_{$field}",
                $field === 'password' ? 'Password changed' : "{$field} updated",
                $user->id,
                $user,
                ['ip_address' => $request->ip()]
            );
        }

        return response()->json([
            'message' => 'Profile updated',
            'user' => UserPayload::make($user->fresh()),
        ]);
    }

    public function uploadProfilePhoto(Request $request): JsonResponse
    {
        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,jpg,png,gif,webp', 'max:5120'],
        ]);

        $user = $request->user();

        // Delete existing profile photo if any
        if ($user->profile_photo_url) {
            $path = parse_url($user->profile_photo_url, PHP_URL_PATH);
            if ($path && str_starts_with($path, '/storage/')) {
                $relativePath = substr($path, strlen('/storage/'));
                Storage::disk('public')->delete($relativePath);
            }
        }

        $file = $request->file('image');
        $path = $file->store('profile-photos', 'public');
        $baseUrl = rtrim(config('app.url'), '/');
        $imageUrl = $baseUrl . '/storage/' . $path;

        $user->profile_photo_url = $imageUrl;
        $user->save();

        ActivityLogService::log('user_account_updates', 'account_update_profile_photo', 'Profile photo updated', $user->id, $user);

        return response()->json([
            'message' => 'Profile photo uploaded successfully',
            'profile_photo_url' => MediaUrlHelper::fixLocalDevPort($imageUrl),
            'user' => UserPayload::make($user->fresh()),
        ], 201);
    }

    public function deactivateSelf(Request $request): JsonResponse
    {
        $request->validate([
            'reason' => 'nullable|string|max:255',
        ]);

        $user = $request->user();

        $user->account_status = 'deactivated';
        $user->save();

        $user->tokens()->delete();

        ActivityLogService::log(
            'auth',
            'self_deactivate',
            $request->reason ?? 'User deactivated own account',
            $user->id,
        );

        return response()->json([
            'message' => 'Account deactivated successfully',
        ], 200);
    }
}
