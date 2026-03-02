<?php

use App\Http\Controllers\Auth\AdminAuthController;
use App\Http\Controllers\Api\PostController;
use App\Http\Controllers\Api\AdminUserController;
use App\Http\Controllers\AuthController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Public routes
Route::post('register', [AuthController::class, 'register']);
Route::post('login', [AuthController::class, 'login']);
Route::post('login-admin', [AdminAuthController::class, 'login']);

Route::get('/hello', function () {
    return response()->json(['message' => 'hello']);
});

// Public: feed posts (no auth required)
Route::get('posts', [PostController::class, 'index']);

// Protected routes (auth:sanctum)
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::post('logout', [AuthController::class, 'logout']);
    Route::post('logout-admin', [AdminAuthController::class, 'logout']);
});

// Admin-only routes (auth:sanctum + admin)
Route::middleware(['auth:sanctum', 'admin'])->group(function () {
    Route::post('register-admin', [AdminAuthController::class, 'register']);
    Route::get('admin/users', [AdminUserController::class, 'index']);
    Route::patch('admin/users/{id}/status', [AdminUserController::class, 'updateStatus']);
    Route::delete('admin/users/{id}', [AdminUserController::class, 'destroy']);
});