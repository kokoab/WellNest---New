<?php

use App\Http\Controllers\Auth\AdminAuthController;
use App\Http\Controllers\Api\PostController;
use App\Http\Controllers\Api\AdminUserController;
use App\Http\Controllers\Api\PostCommentController;
use App\Http\Controllers\Api\VoteController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\AuthController;
use App\Models\Post;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\RecipeController;
use App\Http\Controllers\Api\RecipeRatingController;
use App\Models\User;
use App\Http\Controllers\Api\AdminModerationController;

// Public routes
Route::post('register', [AuthController::class, 'register']);
Route::post('login', [AuthController::class, 'login']);
Route::post('login-admin', [AdminAuthController::class, 'login']);

Route::get('/hello', function () {
    return response()->json(['message' => 'hello']);
});

// Public: feed posts (no auth required)
Route::get('posts', [PostController::class, 'index']);
Route::get('posts/{post}', function (Post $post) {
    $post->load('user:id,first_name,last_name');
    return response()->json([
        'id' => $post->id,
        'content' => $post->content,
        'image_url' => $post->image_url ?? '',
        'recipe_id' => $post->recipe_id,
        'user' => ['name' => $post->user->name ?? ''],
    ]);
});

// Public: list and view recipes and categories (no auth required — show all recipes)
Route::get('categories', [CategoryController::class, 'index']);
Route::get('categories/{category}', [CategoryController::class, 'show']);
Route::get('recipes', [RecipeController::class, 'index']);
Route::get('recipes/{recipe}', [RecipeController::class, 'show']);
Route::get('recipes/{recipe}/ratings', [RecipeRatingController::class, 'index']);

// Protected routes (auth:sanctum)
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::post('logout', [AuthController::class, 'logout']);
    Route::post('logout-admin', [AdminAuthController::class, 'logout']);

    Route::post('recipes', [RecipeController::class, 'create']);
    Route::put('recipes/{recipe}', [RecipeController::class, 'update']);
    Route::delete('recipes/{recipe}', [RecipeController::class, 'delete']);
    Route::post('recipes/{recipe}/images', [RecipeController::class, 'uploadImage']);
    Route::post('recipes/{recipe}/like', [VoteController::class, 'likeRecipe']);
    Route::delete('recipes/{recipe}/like', [VoteController::class, 'unlikeRecipe']);
    Route::post('recipes/{recipe}/report', [ReportController::class, 'reportRecipe']);
    Route::post('recipes/{recipe}/ratings', [RecipeRatingController::class, 'store']);
    Route::get('recipes/{recipe}/ratings/me', [RecipeRatingController::class, 'userRating']);

    Route::post('posts', [PostController::class, 'store']);
    Route::post('posts/{post}/images', [PostController::class, 'uploadImage']);
    Route::post('posts/{post}/like', [VoteController::class, 'likePost']);
    Route::delete('posts/{post}/like', [VoteController::class, 'unlikePost']);
    Route::post('posts/{post}/report', [ReportController::class, 'reportPost']);
    Route::get('posts/{post}/comments', [PostCommentController::class, 'index']);
    Route::post('posts/{post}/comments', [PostCommentController::class, 'store']);

    Route::get('notifications', [NotificationController::class, 'index']);
    Route::get('notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::patch('notifications/{id}/read', [NotificationController::class, 'markAsRead']);
    Route::post('notifications/read-all', [NotificationController::class, 'markAllAsRead']);

    Route::post('users/{user}/report', [ReportController::class, 'reportUser']);
});

// Admin-only routes (auth:sanctum + admin)
Route::middleware(['auth:sanctum', 'admin'])->group(function () {
    Route::post('register-admin', [AdminAuthController::class, 'register']);
    Route::get('admin/users', [AdminUserController::class, 'index']);
    Route::patch('admin/users/{id}/status', [AdminUserController::class, 'updateStatus']);
    Route::delete('admin/users/{id}', [AdminUserController::class, 'destroy']);

    Route::post('categories', [CategoryController::class, 'create']);
    Route::put('categories/{category}', [CategoryController::class, 'update']);
    Route::delete('categories/{category}', [CategoryController::class, 'delete']);

    Route::get('admin/reports', [AdminModerationController::class, 'index']);
    Route::patch('admin/reports/{report}/approve', [AdminModerationController::class, 'approve']);
    Route::patch('admin/reports/{report}/remove-content', [AdminModerationController::class, 'removeContent']);
    Route::patch('admin/reports/{report}/suspend-user', [AdminModerationController::class, 'suspendUser']);
    Route::patch('admin/reports/{report}/unban-user', [AdminModerationController::class, 'unbanUser']);
    Route::patch('admin/reports/{report}/dismiss', [AdminModerationController::class, 'dismiss']);
    Route::delete('admin/reports', [AdminModerationController::class, 'deleteAllReports']);
});
