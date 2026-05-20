<?php

use App\Http\Controllers\Auth\AdminAuthController;
use App\Http\Controllers\Api\PostController;
use App\Http\Controllers\Api\AdminUserController;
use App\Http\Controllers\Api\PostCommentController;
use App\Http\Controllers\Api\VoteController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\AuthController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\RecipeController;
use App\Http\Controllers\Api\RecipeRatingController;
use App\Http\Controllers\Api\AdminModerationController;
use App\Http\Controllers\Api\Activity\LogController;
use App\Http\Controllers\Api\SavedRecipeController;
use App\Http\Controllers\ConversationController;
use App\Http\Controllers\MessageController;
use App\Http\Controllers\MessageAttachmentController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\Api\MealPlannerController;
use Illuminate\Support\Facades\Broadcast;
use App\Http\Controllers\Api\RecipeRankingController;
use App\Http\Controllers\Api\MealPlanController;
use App\Http\Controllers\Api\AdminDashboardController;

// Public: splash / login / signup (and password recovery) only
Route::post('register', [AuthController::class, 'register']);
Route::post('login', [AuthController::class, 'login']);
Route::post('forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('reset-password', [AuthController::class, 'resetPassword']);
Route::post('login-admin', [AdminAuthController::class, 'login']);

// Authenticated app routes (dashboard and all in-app features)
Route::middleware(['auth:sanctum', 'check.account.status'])->group(function () {
    Route::get('/user', [UserController::class, 'currentUser']);
    Route::patch('/user', [AuthController::class, 'updateProfile']);
    Route::post('/user/profile-photo', [AuthController::class, 'uploadProfilePhoto']);
    Route::post('logout', [AuthController::class, 'logout']);
    Route::post('logout-admin', [AdminAuthController::class, 'logout']);

    Route::get('categories', [CategoryController::class, 'index']);
    Route::get('categories/{category}', [CategoryController::class, 'show']);
    Route::post('categories/for-recipe', [CategoryController::class, 'findOrCreateForRecipe']);

    Route::get('recipes', [RecipeController::class, 'index']);
    Route::get('recipes/rankings', [RecipeRankingController::class, 'index']);
    Route::get('recipes/{recipe}', [RecipeController::class, 'show']);
    Route::get('recipes/{recipe}/ratings', [RecipeRatingController::class, 'index']);
    Route::post('recipes', [RecipeController::class, 'create']);
    Route::put('recipes/{recipe}', [RecipeController::class, 'update']);
    Route::delete('recipes/{recipe}', [RecipeController::class, 'delete']);
    Route::post('recipes/{recipe}/images', [RecipeController::class, 'uploadImage']);
    Route::delete('recipes/{recipe}/images/{image}', [RecipeController::class, 'deleteImage']);
    Route::put('recipes/{recipe}/images/reorder', [RecipeController::class, 'reorderImages']);
    Route::post('recipes/{recipe}/steps/{step}/images', [RecipeController::class, 'uploadStepImage']);
    Route::delete('recipes/{recipe}/steps/{step}/images/{image}', [RecipeController::class, 'deleteStepImage']);
    Route::post('recipes/{recipe}/like', [VoteController::class, 'likeRecipe']);
    Route::delete('recipes/{recipe}/like', [VoteController::class, 'unlikeRecipe']);
    Route::post('recipes/{recipe}/report', [ReportController::class, 'reportRecipe']);
    Route::post('recipes/{recipe}/ratings', [RecipeRatingController::class, 'store']);
    Route::get('recipes/{recipe}/ratings/me', [RecipeRatingController::class, 'userRating']);

    Route::get('posts', [PostController::class, 'index']);
    Route::get('posts/{post}', [PostController::class, 'show']);
    Route::post('posts', [PostController::class, 'store']);
    Route::put('posts/{post}', [PostController::class, 'update']);
    Route::delete('posts/{post}', [PostController::class, 'destroy']);
    Route::post('posts/{post}/images', [PostController::class, 'uploadImage']);
    Route::delete('posts/{post}/images/{image}', [PostController::class, 'deleteImage']);
    Route::put('posts/{post}/images/reorder', [PostController::class, 'reorderImages']);
    Route::get('posts/{post}/likes', [VoteController::class, 'getPostLikes']);
    Route::post('posts/{post}/like', [VoteController::class, 'likePost']);
    Route::delete('posts/{post}/like', [VoteController::class, 'unlikePost']);
    Route::post('posts/{post}/report', [ReportController::class, 'reportPost']);
    Route::get('posts/{post}/comments', [PostCommentController::class, 'index']);
    Route::post('posts/{post}/comments', [PostCommentController::class, 'store']);

    Route::get('notifications', [NotificationController::class, 'index']);
    Route::get('notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::patch('notifications/{id}/read', [NotificationController::class, 'markAsRead']);
    Route::post('notifications/read-all', [NotificationController::class, 'markAllAsRead']);

    Route::get('users/search', [UserController::class, 'search']);
    Route::get('users/{user}/followers', [UserController::class, 'followers'])->whereNumber('user');
    Route::get('users/{user}/following', [UserController::class, 'followingList'])->whereNumber('user');
    Route::get('users/{user}', [UserController::class, 'show'])->whereNumber('user');
    Route::post('users/{user}/follow', [UserController::class, 'follow']);
    Route::delete('users/{user}/follow', [UserController::class, 'unfollow']);
    Route::post('users/{user}/report', [ReportController::class, 'reportUser']);

    Route::post('recipes/{recipe}/save', [SavedRecipeController::class, 'save']);
    Route::delete('recipes/{recipe}/save', [SavedRecipeController::class, 'unsave']);
    Route::get('saved-recipes', [SavedRecipeController::class, 'index']);
    Route::get('recipes/{recipe}/saved', [SavedRecipeController::class, 'check']);

    Route::get('meal-plans/export', [MealPlanController::class, 'export']);
    Route::get('meal-plans', [MealPlanController::class, 'index']);
    Route::post('meal-plans', [MealPlanController::class, 'store']);
    Route::post('meal-plans/day-skip', [MealPlanController::class, 'setDaySkip']);
    Route::post('meal-plans/meal-skip', [MealPlanController::class, 'setMealSkip']);
    Route::delete('meal-plans/{mealPlan}', [MealPlanController::class, 'destroy']);

    Route::get('conversations/assistant', [ConversationController::class, 'assistant']);
    Route::get('conversations/unread-count', [ConversationController::class, 'unreadCount']);
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
    Route::post('messages', [MessageController::class, 'store']);
    Route::put('messages/{message}', [MessageController::class, 'update']);
    Route::delete('messages/{message}', [MessageController::class, 'delete']);
    Route::patch('messages/{message}/read', [MessageController::class, 'markAsRead']);
    Route::post('messages/{message}/attachments', [MessageAttachmentController::class, 'upload']);
    Route::post('meal-planner/log', [MealPlannerController::class, 'logAction']);

    Route::get('message-attachments', [MessageAttachmentController::class, 'index']);
    Route::get('message-attachments/{messageAttachment}', [MessageAttachmentController::class, 'show']);
    Route::post('message-attachments', [MessageAttachmentController::class, 'create']);
    Route::put('message-attachments/{messageAttachment}', [MessageAttachmentController::class, 'update']);
    Route::delete('message-attachments/{messageAttachment}', [MessageAttachmentController::class, 'delete']);

    Route::post('/broadcasting/auth', function (Request $request) {
        return Broadcast::auth($request);
    });

    Route::patch('me/deactivate', [UserController::class, 'deactivateSelf']);
});

// Admin-only routes (auth:sanctum + admin)
Route::middleware(['auth:sanctum', 'admin'])->group(function () {
    Route::post('register-admin', [AdminAuthController::class, 'register']);
    Route::get('admin/users', [AdminUserController::class, 'index']);
    Route::patch('admin/users/{user}/status', [AdminUserController::class, 'updateStatus']);
    Route::delete('admin/users/{user}', [AdminUserController::class, 'destroy']);

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

    Route::get('admin/audit-logs', [LogController::class, 'index']);
    Route::get('admin/audit-logs/export', [LogController::class, 'exportCsv']);

    Route::get('admin/recipes/rankings', [RecipeRankingController::class, 'index']);
    Route::get('admin/stats/overview', [AdminDashboardController::class, 'overview']);
    Route::get('admin/stats/user-growth', [AdminDashboardController::class, 'userGrowth']);
    Route::get('admin/stats/post-frequency', [AdminDashboardController::class, 'postFrequency']);
    Route::get('admin/stats/chatbot-interactions', [AdminDashboardController::class, 'chatbotInteractions']);
});
