<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use App\Services\ActivityLogService;

class AuthController extends Controller
{
    //
    public function register(Request $request)
    {
        $request->validate([
            'first_name' => 'required|string|max:255',
            'last_name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
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
        if (($user->status ?? 'active') === 'suspended') {
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
}
