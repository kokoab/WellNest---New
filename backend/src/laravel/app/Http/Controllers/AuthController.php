<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use App\Services\ActivityLogService;

class AuthController extends Controller
{
    //
    public function register(Request $request)
    {
        $request->validate([
            'first_name' => 'required|string|max:255',
            'last_name' => 'required|string|max:255',
            'email' => ['required', 'string', 'email:rfc,dns', 'max:255', 'unique:users,email'],
            'password' => 'required|string|min:8',
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
            'user' => $user,
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
            'user' => $user,
            'token' => $token
        ], 200);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();
        return response()->json(['message' => 'Logged out successfully'], 200);
    }

    public function deleteAccount(Request $request)
    {
        $request->user()->delete();
        ActivityLogService::log('auth', 'delete_account', 'Account deleted successfully', $request->user()->id);
        return response()->json(['message' => 'Account deleted successfully'], 200);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $request->validate([
            'first_name' => 'sometimes|string|max:255',
            'last_name' => 'sometimes|string|max:255',
            'email' => ['sometimes', 'string', 'email:rfc,dns', 'max:255', Rule::unique('users', 'email')->ignore($request->user()->id)],
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

        return response()->json(['message' => 'Profile updated', 'user' => $user]);
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
            'profile_photo_url' => $imageUrl,
            'user' => $user->fresh(),
        ], 201);
    }

    public function deactivateSelf(Request $request): JsonResponse
    {
        $user = $request->user();

        $user->account_status = 'deactivated';
        $user->save();

        $user->tokens()->delete();

        ActivityLogService::log(
            'auth',
            'self_deactivate',
            'User deactivated own account',
            $user->id,
        );

        return response()->json([
            'message' => 'Account deactivated successfully',
        ], 200);
    }
}
