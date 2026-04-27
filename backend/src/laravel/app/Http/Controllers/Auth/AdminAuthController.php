<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use App\Services\ActivityLogService;

class AdminAuthController extends Controller
{
    public function register(Request $request)
    {
        $request->validate([
            'first_name' => 'required|string|max:255',
            'last_name' => 'required|string|max:255',
            'email' => ['required', 'string', 'email:rfc,dns', 'max:255', 'unique:users,email'],
            'password' => 'required|string|min:8',
        ]);

        ActivityLogService::log('admin', 'register', 'Admin registered successfully', null, null, ['email' => $request->email]);
        $admin = User::create([
            'first_name' => $request->first_name,
            'last_name' => $request->last_name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => 'admin',
            'is_admin' => true,
        ]);

        $token = $admin->createToken('auth-token')->plainTextToken;

        return response()->json([
            'message' => 'Admin created successfully',
            'admin' => $admin,
            'token' => $token,
        ], 201);
    }

    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|string|email|max:255',
            'password' => 'required|string|min:8',
        ]);

        $user = User::where('email', $request->email)->first();
        if (!$user || !Hash::check($request->password, $user->password)) {
            ActivityLogService::log('admin', 'login_failed', 'Invalid credentials', $user?->id, null, ['email' => $request->email]);
            return response()->json(['message' => 'Invalid credentials'], 401);
        }

        if ($user->isDeactivatedAccount()) {
            $user->account_status = 'active';
            $user->save();

            ActivityLogService::log('admin', 'reactivate_on_login', 'Admin account reactivated on login', $user->id, null, ['email' => $request->email]);
        }

        if ($user->isSuspendedAccount()) {
            ActivityLogService::log('admin', 'login_failed', 'Account is suspended', $user->id, null, ['email' => $request->email]);
            return response()->json(['message' => 'Account is suspended'], 403);
        }

        if ($user->role !== 'admin') {
            return response()->json(['message' => 'Forbidden. Admin access only.'], 403);
        }

        $token = $user->createToken('auth-token')->plainTextToken;

        ActivityLogService::log('login_attempts', 'login_success', 'Admin login successful', $user->id, null, ['email' => $user->email, 'ip_address' => $request->ip()]);

        return response()->json([
            'message' => 'Login successful',
            'admin' => $user,
            'token' => $token,
        ], 200);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();
        ActivityLogService::log('admin', 'logout', 'Logged out successfully', $request->user()->id);
        return response()->json(['message' => 'Logged out successfully'], 200);
    }
}
