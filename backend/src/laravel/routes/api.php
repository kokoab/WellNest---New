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
use App\Http\Controllers\Api\Activity\LogController;
use App\Http\Controllers\Api\SavedRecipeController;
use App\Http\Controllers\ConversationController;
use App\Http\Controllers\MessageController;
use App\Http\Controllers\MessageAttachmentController;
use App\Http\Controllers\UserController;
use Illuminate\Support\Facades\Broadcast;
use App\Http\Controllers\Api\RecipeRankingController;
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
    $post->load('user:id,first_name,last_name,profile_photo_url');
    return response()->json([
        'id' => $post->id,
        'content' => $post->content,
        'image_url' => $post->image_url ?? '',
        'recipe_id' => $post->recipe_id,
        'created_at' => $post->created_at?->toIso8601String(),
        'user' => [
            'name' => $post->user->name ?? '',
            'profile_photo_url' => $post->user->profile_photo_url ?? null,
        ],
    ]);
});

// Public: list comments for a post (no auth required)
Route::get('posts/{post}/comments', [PostCommentController::class, 'index']);
Route::get('users/{user}', [UserController::class, 'show'])->whereNumber('user');

// Public: list and view recipes and categories (no auth required — show all recipes)
Route::get('categories', [CategoryController::class, 'index']);
Route::get('categories/{category}', [CategoryController::class, 'show']);
Route::get('recipes', [RecipeController::class, 'index']);
// Must be before recipes/{recipe} or "rankings" is captured as the {recipe} id.
Route::get('recipes/rankings', [RecipeRankingController::class, 'index']);
Route::get('recipes/{recipe}', [RecipeController::class, 'show']);
Route::get('recipes/{recipe}/ratings', [RecipeRatingController::class, 'index']);

// Protected routes (auth:sanctum)
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', [UserController::class, 'currentUser']);
    Route::patch('/user', [AuthController::class, 'updateProfile']);
    Route::post('/user/profile-photo', [AuthController::class, 'uploadProfilePhoto']);
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
    Route::get('posts/{post}/likes', [VoteController::class, 'getPostLikes']); // ← new
    Route::post('posts/{post}/like', [VoteController::class, 'likePost']);
    Route::delete('posts/{post}/like', [VoteController::class, 'unlikePost']);
    Route::post('posts/{post}/report', [ReportController::class, 'reportPost']);
    // Comments are listed publicly; posting requires auth.
    Route::post('posts/{post}/comments', [PostCommentController::class, 'store']);

    Route::get('notifications', [NotificationController::class, 'index']);
    Route::get('notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::patch('notifications/{id}/read', [NotificationController::class, 'markAsRead']);
    Route::post('notifications/read-all', [NotificationController::class, 'markAllAsRead']);

    Route::get('users/search', [UserController::class, 'search']);
    Route::post('users/{user}/follow', [UserController::class, 'follow']);
    Route::delete('users/{user}/follow', [UserController::class, 'unfollow']);
    Route::post('users/{user}/report', [ReportController::class, 'reportUser']);

    Route::post('recipes/{recipe}/save', [SavedRecipeController::class, 'save']);
    Route::delete('recipes/{recipe}/save', [SavedRecipeController::class, 'unsave']);
    Route::get('saved-recipes', [SavedRecipeController::class, 'index']);
    Route::get('recipes/{recipe}/saved', [SavedRecipeController::class, 'check']);

    Route::get('conversations/assistant', [ConversationController::class, 'assistant']);
    Route::get('conversations', [ConversationController::class, 'index']);
    Route::get('conversations/{conversation}', [ConversationController::class, 'show']);
    Route::post('conversations', [ConversationController::class, 'create']);
    Route::put('conversations/{conversation}', [ConversationController::class, 'update']);
    Route::delete('conversations/{conversation}', [ConversationController::class, 'delete']);

    Route::get('conversations/{conversation}/messages', [MessageController::class, 'indexByConversation']);
    Route::post('conversations/{conversation}/messages', [MessageController::class, 'store']);
    Route::patch('conversations/{conversation}/messages/read', [MessageController::class, 'markConversationAsRead']);

    Route::get('messages', [MessageController::class, 'index']);
    Route::get('messages/{message}', [MessageController::class, 'show']);
    Route::post('messages', [MessageController::class, 'create']);
    Route::put('messages/{message}', [MessageController::class, 'update']);
    Route::delete('messages/{message}', [MessageController::class, 'delete']);
    Route::patch('messages/{message}/read', [MessageController::class, 'markAsRead']);
    Route::post('messages/{message}/attachments', [MessageAttachmentController::class, 'upload']);

    Route::get('message-attachments', [MessageAttachmentController::class, 'index']);
    Route::get('message-attachments/{messageAttachment}', [MessageAttachmentController::class, 'show']);
    Route::post('message-attachments', [MessageAttachmentController::class, 'create']);
    Route::put('message-attachments/{messageAttachment}', [MessageAttachmentController::class, 'update']);
    Route::delete('message-attachments/{messageAttachment}', [MessageAttachmentController::class, 'delete']);

    // In your auth:sanctum group in routes/api.php
    Route::post('/broadcasting/auth', function (Request $request) {
        return Broadcast::auth($request);
    });


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

    // Audit logs API (aliases to activity logs controller/actions)
    Route::get('admin/audit-logs', [LogController::class, 'index']);
    Route::get('admin/audit-logs/export', [LogController::class, 'exportCsv']);

    // Kept for backward compatibility
    Route::get('admin/activity-logs', [LogController::class, 'index']);
    Route::get('admin/activity-logs/export', [LogController::class, 'exportCsv']);

    Route::get('admin/recipes/rankings', [RecipeRankingController::class, 'index']);
});