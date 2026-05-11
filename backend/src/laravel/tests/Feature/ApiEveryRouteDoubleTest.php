<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Conversation;
use App\Models\MealPlan;
use App\Models\Message;
use App\Models\MessageAttachment;
use App\Models\Post;
use App\Models\Recipe;
use App\Models\RecipeStep;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Each API route from routes/api.php is exercised twice (redundant by design).
 * PHPUnit counts each data set as its own test.
 */
class ApiEveryRouteDoubleTest extends TestCase
{
    use RefreshDatabase;

    public static function routeTwiceProvider(): \Generator
    {
        foreach (self::routeKeys() as $key) {
            yield $key.'__a' => [$key, 0];
            yield $key.'__b' => [$key, 1];
        }
    }

    /** @dataProvider routeTwiceProvider */
    public function test_each_api_route_executed_twice(string $routeKey, int $round): void
    {
        $this->invokeRouteKey($routeKey, $round);
    }

    /**
     * @return list<string>
     */
    private static function routeKeys(): array
    {
        return [
            'POST_register',
            'POST_login',
            'POST_forgot_password',
            'POST_reset_password',
            'POST_login_admin',
            'GET_posts',
            'GET_posts_show',
            'GET_posts_comments',
            'GET_users_show',
            'GET_categories',
            'GET_categories_show',
            'GET_recipes',
            'GET_recipes_rankings',
            'GET_recipes_show',
            'GET_recipes_ratings',
            'GET_user',
            'PATCH_user',
            'POST_user_profile_photo',
            'POST_logout',
            'POST_logout_admin',
            'POST_categories_for_recipe',
            'POST_recipes',
            'PUT_recipes',
            'DELETE_recipes',
            'POST_recipes_images',
            'DELETE_recipes_images',
            'PUT_recipes_images_reorder',
            'POST_recipes_steps_images',
            'DELETE_recipes_steps_images',
            'POST_recipes_like',
            'DELETE_recipes_like',
            'POST_recipes_report',
            'POST_recipes_ratings',
            'GET_recipes_ratings_me',
            'POST_posts',
            'PUT_posts',
            'DELETE_posts',
            'POST_posts_images',
            'DELETE_posts_images',
            'PUT_posts_images_reorder',
            'GET_posts_likes',
            'POST_posts_like',
            'DELETE_posts_like',
            'POST_posts_report',
            'POST_posts_comments',
            'GET_notifications',
            'GET_notifications_unread_count',
            'PATCH_notifications_read',
            'POST_notifications_read_all',
            'GET_users_search',
            'POST_users_follow',
            'DELETE_users_follow',
            'POST_users_report',
            'POST_recipes_save',
            'DELETE_recipes_save',
            'GET_saved_recipes',
            'GET_recipes_saved',
            'GET_meal_plans_export',
            'GET_meal_plans',
            'POST_meal_plans',
            'POST_meal_plans_day_skip',
            'POST_meal_plans_meal_skip',
            'DELETE_meal_plans',
            'GET_conversations_assistant',
            'GET_conversations',
            'GET_conversations_show',
            'POST_conversations',
            'PUT_conversations',
            'DELETE_conversations',
            'GET_conversations_messages',
            'POST_conversations_messages',
            'PATCH_conversations_messages_read',
            'GET_messages',
            'GET_messages_show',
            'POST_messages',
            'PUT_messages',
            'DELETE_messages',
            'PATCH_messages_read',
            'POST_messages_attachments',
            'POST_meal_planner_log',
            'GET_message_attachments',
            'GET_message_attachments_show',
            'POST_message_attachments',
            'PUT_message_attachments',
            'DELETE_message_attachments',
            'POST_broadcasting_auth',
            'PATCH_me_deactivate',
            'POST_register_admin',
            'GET_admin_users',
            'PATCH_admin_users_status',
            'DELETE_admin_users',
            'POST_admin_categories',
            'PUT_admin_categories',
            'DELETE_admin_categories',
            'GET_admin_reports',
            'PATCH_admin_reports_approve',
            'PATCH_admin_reports_remove_content',
            'PATCH_admin_reports_suspend_user',
            'PATCH_admin_reports_unban_user',
            'PATCH_admin_reports_dismiss',
            'DELETE_admin_reports',
            'GET_admin_audit_logs',
            'GET_admin_audit_logs_export',
            'GET_admin_activity_logs',
            'GET_admin_activity_logs_export',
            'GET_admin_recipes_rankings',
            'GET_admin_stats_overview',
            'GET_admin_stats_user_growth',
            'GET_admin_stats_post_frequency',
            'GET_admin_stats_chatbot_interactions',
        ];
    }

    private function invokeRouteKey(string $key, int $round): void
    {
        match ($key) {
            'POST_register' => $this->dupPostRegister($round),
            'POST_login' => $this->dupPostLogin($round),
            'POST_forgot_password' => $this->dupPostForgotPassword($round),
            'POST_reset_password' => $this->dupPostResetPassword($round),
            'POST_login_admin' => $this->dupPostLoginAdmin($round),
            'GET_posts' => $this->dupGetPosts($round),
            'GET_posts_show' => $this->dupGetPostsShow($round),
            'GET_posts_comments' => $this->dupGetPostsComments($round),
            'GET_users_show' => $this->dupGetUsersShow($round),
            'GET_categories' => $this->dupGetCategories($round),
            'GET_categories_show' => $this->dupGetCategoriesShow($round),
            'GET_recipes' => $this->dupGetRecipes($round),
            'GET_recipes_rankings' => $this->dupGetRecipesRankings($round),
            'GET_recipes_show' => $this->dupGetRecipesShow($round),
            'GET_recipes_ratings' => $this->dupGetRecipesRatings($round),
            'GET_user' => $this->dupGetUser($round),
            'PATCH_user' => $this->dupPatchUser($round),
            'POST_user_profile_photo' => $this->dupPostProfilePhoto($round),
            'POST_logout' => $this->dupPostLogout($round),
            'POST_logout_admin' => $this->dupPostLogoutAdmin($round),
            'POST_categories_for_recipe' => $this->dupPostCategoriesForRecipe($round),
            'POST_recipes' => $this->dupPostRecipes($round),
            'PUT_recipes' => $this->dupPutRecipes($round),
            'DELETE_recipes' => $this->dupDeleteRecipes($round),
            'POST_recipes_images' => $this->dupPostRecipeImages($round),
            'DELETE_recipes_images' => $this->dupDeleteRecipeImages($round),
            'PUT_recipes_images_reorder' => $this->dupPutRecipeImagesReorder($round),
            'POST_recipes_steps_images' => $this->dupPostRecipeStepImages($round),
            'DELETE_recipes_steps_images' => $this->dupDeleteRecipeStepImages($round),
            'POST_recipes_like' => $this->dupPostRecipeLike($round),
            'DELETE_recipes_like' => $this->dupDeleteRecipeLike($round),
            'POST_recipes_report' => $this->dupPostRecipeReport($round),
            'POST_recipes_ratings' => $this->dupPostRecipeRatings($round),
            'GET_recipes_ratings_me' => $this->dupGetRecipeRatingsMe($round),
            'POST_posts' => $this->dupPostPosts($round),
            'PUT_posts' => $this->dupPutPosts($round),
            'DELETE_posts' => $this->dupDeletePosts($round),
            'POST_posts_images' => $this->dupPostPostImages($round),
            'DELETE_posts_images' => $this->dupDeletePostImages($round),
            'PUT_posts_images_reorder' => $this->dupPutPostImagesReorder($round),
            'GET_posts_likes' => $this->dupGetPostLikes($round),
            'POST_posts_like' => $this->dupPostPostLike($round),
            'DELETE_posts_like' => $this->dupDeletePostLike($round),
            'POST_posts_report' => $this->dupPostPostReport($round),
            'POST_posts_comments' => $this->dupPostPostComments($round),
            'GET_notifications' => $this->dupGetNotifications($round),
            'GET_notifications_unread_count' => $this->dupGetNotificationsUnread($round),
            'PATCH_notifications_read' => $this->dupPatchNotificationRead($round),
            'POST_notifications_read_all' => $this->dupPostNotificationsReadAll($round),
            'GET_users_search' => $this->dupGetUsersSearch($round),
            'POST_users_follow' => $this->dupPostUsersFollow($round),
            'DELETE_users_follow' => $this->dupDeleteUsersFollow($round),
            'POST_users_report' => $this->dupPostUsersReport($round),
            'POST_recipes_save' => $this->dupPostRecipesSave($round),
            'DELETE_recipes_save' => $this->dupDeleteRecipesSave($round),
            'GET_saved_recipes' => $this->dupGetSavedRecipes($round),
            'GET_recipes_saved' => $this->dupGetRecipesSaved($round),
            'GET_meal_plans_export' => $this->dupGetMealPlansExport($round),
            'GET_meal_plans' => $this->dupGetMealPlans($round),
            'POST_meal_plans' => $this->dupPostMealPlans($round),
            'POST_meal_plans_day_skip' => $this->dupPostMealPlansDaySkip($round),
            'POST_meal_plans_meal_skip' => $this->dupPostMealPlansMealSkip($round),
            'DELETE_meal_plans' => $this->dupDeleteMealPlans($round),
            'GET_conversations_assistant' => $this->dupGetConversationsAssistant($round),
            'GET_conversations' => $this->dupGetConversations($round),
            'GET_conversations_show' => $this->dupGetConversationsShow($round),
            'POST_conversations' => $this->dupPostConversations($round),
            'PUT_conversations' => $this->dupPutConversations($round),
            'DELETE_conversations' => $this->dupDeleteConversations($round),
            'GET_conversations_messages' => $this->dupGetConversationsMessages($round),
            'POST_conversations_messages' => $this->dupPostConversationsMessages($round),
            'PATCH_conversations_messages_read' => $this->dupPatchConversationsMessagesRead($round),
            'GET_messages' => $this->dupGetMessages($round),
            'GET_messages_show' => $this->dupGetMessagesShow($round),
            'POST_messages' => $this->dupPostMessages($round),
            'PUT_messages' => $this->dupPutMessages($round),
            'DELETE_messages' => $this->dupDeleteMessages($round),
            'PATCH_messages_read' => $this->dupPatchMessagesRead($round),
            'POST_messages_attachments' => $this->dupPostMessagesAttachments($round),
            'POST_meal_planner_log' => $this->dupPostMealPlannerLog($round),
            'GET_message_attachments' => $this->dupGetMessageAttachments($round),
            'GET_message_attachments_show' => $this->dupGetMessageAttachmentsShow($round),
            'POST_message_attachments' => $this->dupPostMessageAttachments($round),
            'PUT_message_attachments' => $this->dupPutMessageAttachments($round),
            'DELETE_message_attachments' => $this->dupDeleteMessageAttachments($round),
            'POST_broadcasting_auth' => $this->dupPostBroadcastingAuth($round),
            'PATCH_me_deactivate' => $this->dupPatchMeDeactivate($round),
            'POST_register_admin' => $this->dupPostRegisterAdmin($round),
            'GET_admin_users' => $this->dupGetAdminUsers($round),
            'PATCH_admin_users_status' => $this->dupPatchAdminUsersStatus($round),
            'DELETE_admin_users' => $this->dupDeleteAdminUsers($round),
            'POST_admin_categories' => $this->dupPostAdminCategories($round),
            'PUT_admin_categories' => $this->dupPutAdminCategories($round),
            'DELETE_admin_categories' => $this->dupDeleteAdminCategories($round),
            'GET_admin_reports' => $this->dupGetAdminReports($round),
            'PATCH_admin_reports_approve' => $this->dupPatchAdminReportsApprove($round),
            'PATCH_admin_reports_remove_content' => $this->dupPatchAdminReportsRemove($round),
            'PATCH_admin_reports_suspend_user' => $this->dupPatchAdminReportsSuspend($round),
            'PATCH_admin_reports_unban_user' => $this->dupPatchAdminReportsUnban($round),
            'PATCH_admin_reports_dismiss' => $this->dupPatchAdminReportsDismiss($round),
            'DELETE_admin_reports' => $this->dupDeleteAdminReports($round),
            'GET_admin_audit_logs' => $this->dupGetAdminAuditLogs($round),
            'GET_admin_audit_logs_export' => $this->dupGetAdminAuditLogsExport($round),
            'GET_admin_activity_logs' => $this->dupGetAdminActivityLogs($round),
            'GET_admin_activity_logs_export' => $this->dupGetAdminActivityLogsExport($round),
            'GET_admin_recipes_rankings' => $this->dupGetAdminRecipesRankings($round),
            'GET_admin_stats_overview' => $this->dupGetAdminStatsOverview($round),
            'GET_admin_stats_user_growth' => $this->dupGetAdminStatsUserGrowth($round),
            'GET_admin_stats_post_frequency' => $this->dupGetAdminStatsPostFrequency($round),
            'GET_admin_stats_chatbot_interactions' => $this->dupGetAdminStatsChatbot($round),
            default => $this->fail('Unknown route key: '.$key),
        };
    }

    private function assistantBot(): User
    {
        return User::query()->firstOrCreate(
            ['email' => config('assistant.bot_email', 'assistant@wellnest.local')],
            [
                'first_name' => 'WellNest',
                'last_name' => 'Assistant',
                'password' => Hash::make('password'),
                'role' => 'user',
                'status' => 'active',
                'account_status' => 'active',
                'is_admin' => false,
            ]
        );
    }

    private function actingFreshUser(): User
    {
        $u = $this->createUser();
        Sanctum::actingAs($u);

        return $u;
    }

    private function actingFreshAdmin(): User
    {
        $a = $this->createAdmin();
        Sanctum::actingAs($a);

        return $a;
    }

    private function dupPostRegister(int $round): void
    {
        $email = 'reg'.$round.uniqid('', true).'@example.com';
        $this->postJson('api/register', [
            'first_name' => 'T',
            'last_name' => 'U',
            'email' => $email,
            'password' => 'password123',
            'accepted_terms' => true,
        ])->assertCreated();
    }

    private function dupPostLogin(int $round): void
    {
        $u = $this->createUser(['email' => "login{$round}@example.com", 'password' => Hash::make('password123')]);
        $this->postJson('api/login', [
            'email' => $u->email,
            'password' => 'password123',
        ])->assertOk();
    }

    private function dupPostForgotPassword(int $round): void
    {
        $this->createUser(['email' => "fp{$round}@example.com"]);
        $this->postJson('api/forgot-password', ['email' => "fp{$round}@example.com"])->assertOk();
    }

    private function dupPostResetPassword(int $round): void
    {
        $email = "rs{$round}@example.com";
        $this->createUser(['email' => $email, 'password' => Hash::make('oldpass123')]);
        $code = (string) (600000 + $round);
        \Illuminate\Support\Facades\Cache::put(
            'password-reset-code:'.strtolower($email),
            Hash::make($code),
            now()->addMinutes(10)
        );
        $this->postJson('api/reset-password', [
            'email' => $email,
            'code' => $code,
            'password' => 'newpass12345',
            'password_confirmation' => 'newpass12345',
        ])->assertOk();
    }

    private function dupPostLoginAdmin(int $round): void
    {
        $a = $this->createAdmin(['email' => "adm{$round}@example.com", 'password' => Hash::make('adminpass1')]);
        $this->postJson('api/login-admin', [
            'email' => $a->email,
            'password' => 'adminpass1',
        ])->assertOk();
    }

    private function dupGetPosts(int $round): void
    {
        $u = $this->createUser();
        Post::create([
            'user_id' => $u->id,
            'content' => 'c'.$round,
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->getJson('api/posts?per_page=5')->assertOk();
    }

    private function dupGetPostsShow(int $round): void
    {
        $u = $this->createUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 's'.$round,
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->getJson("api/posts/{$p->id}")->assertOk();
    }

    private function dupGetPostsComments(int $round): void
    {
        $u = $this->createUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 'p'.$round,
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->getJson("api/posts/{$p->id}/comments")->assertOk();
    }

    private function dupGetUsersShow(int $round): void
    {
        $u = $this->createUser(['first_name' => 'Pub'.$round]);
        $this->getJson("api/users/{$u->id}")->assertOk();
    }

    private function dupGetCategories(int $round): void
    {
        Category::factory()->create(['name' => 'CatDup'.$round]);
        $this->getJson('api/categories')->assertOk();
    }

    private function dupGetCategoriesShow(int $round): void
    {
        $c = Category::factory()->create(['name' => 'ShowCat'.$round]);
        $this->getJson("api/categories/{$c->id}")->assertOk();
    }

    private function dupGetRecipes(int $round): void
    {
        $this->createRecipe(['title' => 'R'.$round]);
        $this->getJson('api/recipes?per_page=3')->assertOk();
    }

    private function dupGetRecipesRankings(int $round): void
    {
        $this->getJson('api/recipes/rankings?window=all&mode=combined')->assertOk();
    }

    private function dupGetRecipesShow(int $round): void
    {
        $r = $this->createRecipe(['title' => 'Show'.$round]);
        $this->getJson("api/recipes/{$r->id}")->assertOk();
    }

    private function dupGetRecipesRatings(int $round): void
    {
        $r = $this->createRecipe();
        $u = $this->createUser();
        $r->ratings()->create(['user_id' => $u->id, 'rating' => 4, 'comment' => 'x'.$round]);
        $this->getJson("api/recipes/{$r->id}/ratings")->assertOk();
    }

    private function dupGetUser(int $round): void
    {
        $u = $this->actingFreshUser();
        $this->getJson('api/user')->assertOk()->assertJsonPath('id', $u->id);
    }

    private function dupPatchUser(int $round): void
    {
        $u = $this->actingFreshUser();
        $this->patchJson('api/user', [
            'first_name' => 'N'.$round,
            'last_name' => 'L'.$round,
        ])->assertOk();
    }

    private function dupPostProfilePhoto(int $round): void
    {
        Storage::fake('public');
        $this->actingFreshUser();
        $this->postJson('api/user/profile-photo', [
            'image' => UploadedFile::fake()->create('p'.$round.'.jpg', 50, 'image/jpeg'),
        ])->assertCreated();
    }

    private function dupPostLogout(int $round): void
    {
        $u = $this->createUser();
        $u->createToken('t'.$round);
        Sanctum::actingAs($u);
        $this->postJson('api/logout')->assertOk();
    }

    private function dupPostLogoutAdmin(int $round): void
    {
        $a = $this->createAdmin();
        $a->createToken('adm'.$round);
        Sanctum::actingAs($a);
        $this->postJson('api/logout-admin')->assertOk();
    }

    private function dupPostCategoriesForRecipe(int $round): void
    {
        $this->actingFreshUser();
        $this->postJson('api/categories/for-recipe', [
            'name' => 'ForRecipe'.$round.uniqid(),
        ])->assertSuccessful();
    }

    private function dupPostRecipes(int $round): void
    {
        $u = $this->actingFreshUser();
        $cat = Category::factory()->create();
        $this->postJson('api/recipes', [
            'category_id' => $cat->id,
            'title' => 'NewR'.$round.uniqid(),
            'description' => 'd',
            'instructions' => 'do it',
            'prep_time' => 10,
        ])->assertCreated();
    }

    private function dupPutRecipes(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id, 'title' => 'T'.$round]);
        $this->putJson("api/recipes/{$r->id}", [
            'title' => 'U'.$round,
            'instructions' => 'still good',
            'prep_time' => 12,
        ])->assertOk();
    }

    private function dupDeleteRecipes(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id]);
        $this->deleteJson("api/recipes/{$r->id}")->assertOk();
    }

    private function dupPostRecipeImages(int $round): void
    {
        Storage::fake('public');
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id]);
        $this->post("api/recipes/{$r->id}/images", [
            'image' => UploadedFile::fake()->create('ri'.$round.'.jpg', 50, 'image/jpeg'),
        ])->assertCreated();
    }

    private function dupDeleteRecipeImages(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id]);
        $img = $r->images()->create(['path' => 'recipes/d'.$round.'.jpg', 'sort_order' => 0]);
        $this->deleteJson("api/recipes/{$r->id}/images/{$img->id}")->assertOk();
    }

    private function dupPutRecipeImagesReorder(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id]);
        $a = $r->images()->create(['path' => 'r/a'.$round.'.jpg', 'sort_order' => 0]);
        $b = $r->images()->create(['path' => 'r/b'.$round.'.jpg', 'sort_order' => 1]);
        $this->putJson("api/recipes/{$r->id}/images/reorder", [
            'image_ids' => [$b->id, $a->id],
        ])->assertOk();
    }

    private function dupPostRecipeStepImages(int $round): void
    {
        Storage::fake('public');
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id]);
        $step = RecipeStep::create([
            'recipe_id' => $r->id,
            'sort_order' => 0,
            'title' => 'S',
            'instructions' => 'i',
            'prep_time_minutes' => 1,
        ]);
        $this->post("api/recipes/{$r->id}/steps/{$step->id}/images", [
            'image' => UploadedFile::fake()->create('st'.$round.'.jpg', 50, 'image/jpeg'),
        ])->assertCreated();
    }

    private function dupDeleteRecipeStepImages(int $round): void
    {
        Storage::fake('public');
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id]);
        $step = RecipeStep::create([
            'recipe_id' => $r->id,
            'sort_order' => 0,
            'title' => 'S',
            'instructions' => 'i',
            'prep_time_minutes' => 1,
        ]);
        $img = $step->images()->create(['path' => 'steps/x'.$round.'.jpg', 'sort_order' => 0]);
        $this->deleteJson("api/recipes/{$r->id}/steps/{$step->id}/images/{$img->id}")->assertOk();
    }

    private function dupPostRecipeLike(int $round): void
    {
        $u = $this->actingFreshUser();
        $owner = $this->createUser();
        $r = $this->createRecipe(['user_id' => $owner->id]);
        $this->postJson("api/recipes/{$r->id}/like")->assertCreated();
    }

    private function dupDeleteRecipeLike(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $this->postJson("api/recipes/{$r->id}/like")->assertCreated();
        $this->deleteJson("api/recipes/{$r->id}/like")->assertOk();
    }

    private function dupPostRecipeReport(int $round): void
    {
        $this->createAdmin();
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $this->postJson("api/recipes/{$r->id}/report", [
            'reason' => 'r'.$round,
        ])->assertCreated();
    }

    private function dupPostRecipeRatings(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $this->postJson("api/recipes/{$r->id}/ratings", [
            'rating' => 4,
            'comment' => 'c'.$round,
        ])->assertSuccessful();
    }

    private function dupGetRecipeRatingsMe(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $r->ratings()->create(['user_id' => $u->id, 'rating' => 3, 'comment' => null]);
        $this->getJson("api/recipes/{$r->id}/ratings/me")->assertOk();
    }

    private function dupPostPosts(int $round): void
    {
        $this->actingFreshUser();
        $this->postJson('api/posts', [
            'content' => 'Post body '.$round,
        ])->assertCreated();
    }

    private function dupPutPosts(int $round): void
    {
        $u = $this->actingFreshUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 'o',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->putJson("api/posts/{$p->id}", [
            'content' => 'updated '.$round,
        ])->assertOk();
    }

    private function dupDeletePosts(int $round): void
    {
        $u = $this->actingFreshUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 'd',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->deleteJson("api/posts/{$p->id}")->assertOk();
    }

    private function dupPostPostImages(int $round): void
    {
        Storage::fake('public');
        $u = $this->actingFreshUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 'i',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->postJson("api/posts/{$p->id}/images", [
            'image' => UploadedFile::fake()->create('pi'.$round.'.jpg', 50, 'image/jpeg'),
        ])->assertCreated();
    }

    private function dupDeletePostImages(int $round): void
    {
        $u = $this->actingFreshUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 'i',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $img = $p->images()->create(['path' => 'posts/dp'.$round.'.jpg', 'sort_order' => 0]);
        $this->deleteJson("api/posts/{$p->id}/images/{$img->id}")->assertOk();
    }

    private function dupPutPostImagesReorder(int $round): void
    {
        $u = $this->actingFreshUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 'i',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $a = $p->images()->create(['path' => 'p/a'.$round.'.jpg', 'sort_order' => 0]);
        $b = $p->images()->create(['path' => 'p/b'.$round.'.jpg', 'sort_order' => 1]);
        $this->putJson("api/posts/{$p->id}/images/reorder", [
            'image_ids' => [$b->id, $a->id],
        ])->assertOk();
    }

    private function dupGetPostLikes(int $round): void
    {
        $u = $this->actingFreshUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 'l',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->getJson("api/posts/{$p->id}/likes")->assertOk();
    }

    private function dupPostPostLike(int $round): void
    {
        $author = $this->createUser();
        $fan = $this->actingFreshUser();
        $p = Post::create([
            'user_id' => $author->id,
            'content' => 'l',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->postJson("api/posts/{$p->id}/like")->assertCreated();
    }

    private function dupDeletePostLike(int $round): void
    {
        $author = $this->createUser();
        $fan = $this->actingFreshUser();
        $p = Post::create([
            'user_id' => $author->id,
            'content' => 'l',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->postJson("api/posts/{$p->id}/like")->assertCreated();
        $this->deleteJson("api/posts/{$p->id}/like")->assertOk();
    }

    private function dupPostPostReport(int $round): void
    {
        $this->createAdmin();
        $u = $this->actingFreshUser();
        $author = $this->createUser();
        $p = Post::create([
            'user_id' => $author->id,
            'content' => 'l',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->postJson("api/posts/{$p->id}/report", ['reason' => 'x'.$round])->assertCreated();
    }

    private function dupPostPostComments(int $round): void
    {
        $u = $this->actingFreshUser();
        $author = $this->createUser();
        $p = Post::create([
            'user_id' => $author->id,
            'content' => 'l',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->postJson("api/posts/{$p->id}/comments", [
            'comment' => 'hi '.$round,
        ])->assertCreated();
    }

    private function dupGetNotifications(int $round): void
    {
        $this->actingFreshUser();
        $this->getJson('api/notifications')->assertOk();
    }

    private function dupGetNotificationsUnread(int $round): void
    {
        $this->actingFreshUser();
        $this->getJson('api/notifications/unread-count')->assertOk();
    }

    private function dupPatchNotificationRead(int $round): void
    {
        $u = $this->actingFreshUser();
        $id = (string) Str::uuid();
        DB::table('notifications')->insert([
            'id' => $id,
            'type' => 'App\\Notifications\\NewMessageNotification',
            'notifiable_type' => User::class,
            'notifiable_id' => $u->id,
            'data' => json_encode(['type' => 'new_message', 'message' => 'm'.$round]),
            'read_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->patchJson("api/notifications/{$id}/read")->assertOk();
    }

    private function dupPostNotificationsReadAll(int $round): void
    {
        $this->actingFreshUser();
        $this->postJson('api/notifications/read-all')->assertOk();
    }

    private function dupGetUsersSearch(int $round): void
    {
        $this->createUser(['first_name' => 'Searchable'.$round, 'last_name' => 'X']);
        $this->actingFreshUser();
        $this->getJson('api/users/search?q=Searchable')->assertOk();
    }

    private function dupPostUsersFollow(int $round): void
    {
        $u = $this->actingFreshUser();
        $other = $this->createUser(['email' => "fol{$round}@example.com"]);
        $this->postJson("api/users/{$other->id}/follow")->assertCreated();
    }

    private function dupDeleteUsersFollow(int $round): void
    {
        $u = $this->actingFreshUser();
        $other = $this->createUser(['email' => "uf{$round}@example.com"]);
        $u->following()->attach($other->id);
        $this->deleteJson("api/users/{$other->id}/follow")->assertOk();
    }

    private function dupPostUsersReport(int $round): void
    {
        $this->createAdmin();
        $u = $this->actingFreshUser();
        $other = $this->createUser(['email' => "rep{$round}@example.com"]);
        $this->postJson("api/users/{$other->id}/report", [
            'reason' => 'bad'.$round,
        ])->assertCreated();
    }

    private function dupPostRecipesSave(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $this->postJson("api/recipes/{$r->id}/save")->assertCreated();
    }

    private function dupDeleteRecipesSave(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $u->savedRecipes()->syncWithoutDetaching([$r->id]);
        $this->deleteJson("api/recipes/{$r->id}/save")->assertOk();
    }

    private function dupGetSavedRecipes(int $round): void
    {
        $this->actingFreshUser();
        $this->getJson('api/saved-recipes')->assertOk();
    }

    private function dupGetRecipesSaved(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $this->getJson("api/recipes/{$r->id}/saved")->assertOk();
    }

    private function dupGetMealPlansExport(int $round): void
    {
        $u = $this->actingFreshUser();
        $ws = now()->startOfWeek()->toDateString();
        $this->getJson('api/meal-plans/export?week_start='.$ws)->assertOk();
    }

    private function dupGetMealPlans(int $round): void
    {
        $this->actingFreshUser();
        $ws = now()->startOfWeek()->toDateString();
        $this->getJson('api/meal-plans?week_start='.$ws)->assertOk();
    }

    private function dupPostMealPlans(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $date = now()->addDays(30 + $round)->toDateString();
        $this->postJson('api/meal-plans', [
            'recipe_id' => $r->id,
            'planned_date' => $date,
            'meal_slot' => 'dinner',
        ])->assertSuccessful();
    }

    private function dupPostMealPlansDaySkip(int $round): void
    {
        $this->actingFreshUser();
        $d = now()->addDays(40 + $round)->toDateString();
        $this->postJson('api/meal-plans/day-skip', [
            'planned_date' => $d,
            'did_not_eat' => true,
        ])->assertOk();
    }

    private function dupPostMealPlansMealSkip(int $round): void
    {
        $this->actingFreshUser();
        $d = now()->addDays(50 + $round)->toDateString();
        $this->postJson('api/meal-plans/meal-skip', [
            'planned_date' => $d,
            'meal_slot' => 'breakfast',
            'skipped' => true,
        ])->assertOk();
    }

    private function dupDeleteMealPlans(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $plan = MealPlan::create([
            'user_id' => $u->id,
            'recipe_id' => $r->id,
            'planned_date' => now()->addDays(60 + $round)->toDateString(),
            'meal_slot' => 'lunch',
        ]);
        $this->deleteJson("api/meal-plans/{$plan->id}")->assertOk();
    }

    private function dupGetConversationsAssistant(int $round): void
    {
        $this->assistantBot();
        $this->actingFreshUser();
        $this->getJson('api/conversations/assistant')->assertOk();
    }

    private function dupGetConversations(int $round): void
    {
        $this->actingFreshUser();
        $this->getJson('api/conversations')->assertOk();
    }

    private function dupGetConversationsShow(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $this->getJson("api/conversations/{$c->id}")->assertOk();
    }

    private function dupPostConversations(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser(['email' => "conv{$round}@example.com"]);
        $this->postJson('api/conversations', ['user_id' => $o->id])->assertCreated();
    }

    private function dupPutConversations(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $this->putJson("api/conversations/{$c->id}", [])->assertOk();
    }

    private function dupDeleteConversations(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $this->deleteJson("api/conversations/{$c->id}")->assertNoContent();
    }

    private function dupGetConversationsMessages(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $this->getJson("api/conversations/{$c->id}/messages")->assertOk();
    }

    private function dupPostConversationsMessages(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $this->postJson("api/conversations/{$c->id}/messages", [
            'content' => 'm'.$round,
        ])->assertCreated();
    }

    private function dupPatchConversationsMessagesRead(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $this->patchJson("api/conversations/{$c->id}/messages/read")->assertOk();
    }

    private function dupGetMessages(int $round): void
    {
        $this->dupPostConversationsMessages($round);
        $this->getJson('api/messages')->assertOk();
    }

    private function dupGetMessagesShow(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $m = Message::create([
            'conversation_id' => $c->id,
            'user_id' => $u->id,
            'content' => 'show'.$round,
        ]);
        $this->getJson("api/messages/{$m->id}")->assertOk();
    }

    private function dupPostMessages(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $this->postJson('api/messages', [
            'conversation_id' => $c->id,
            'content' => 'legacy '.$round,
        ])->assertCreated();
    }

    private function dupPutMessages(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $m = Message::create([
            'conversation_id' => $c->id,
            'user_id' => $u->id,
            'content' => 'old',
        ]);
        $this->putJson("api/messages/{$m->id}", ['content' => 'new '.$round])->assertOk();
    }

    private function dupDeleteMessages(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $m = Message::create([
            'conversation_id' => $c->id,
            'user_id' => $u->id,
            'content' => 'del',
        ]);
        $this->deleteJson("api/messages/{$m->id}")->assertNoContent();
    }

    private function dupPatchMessagesRead(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $m = Message::create([
            'conversation_id' => $c->id,
            'user_id' => $o->id,
            'content' => 'from other',
        ]);
        $this->patchJson("api/messages/{$m->id}/read")->assertOk();
    }

    private function dupPostMessagesAttachments(int $round): void
    {
        Storage::fake('public');
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $m = Message::create([
            'conversation_id' => $c->id,
            'user_id' => $u->id,
            'content' => 'att',
        ]);
        $this->post("api/messages/{$m->id}/attachments", [
            'file' => UploadedFile::fake()->create('f'.$round.'.jpg', 50, 'image/jpeg'),
        ])->assertCreated();
    }

    private function dupPostMealPlannerLog(int $round): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $d = now()->addDays(7)->toDateString();
        $ws = now()->startOfWeek()->toDateString();
        $this->postJson('api/meal-planner/log', [
            'action' => 'assign_recipe',
            'day' => $d,
            'week_start' => $ws,
            'recipe_id' => $r->id,
        ])->assertSuccessful();
    }

    private function dupGetMessageAttachments(int $round): void
    {
        $this->actingFreshUser();
        $this->getJson('api/message-attachments')->assertOk();
    }

    private function dupGetMessageAttachmentsShow(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $m = Message::create([
            'conversation_id' => $c->id,
            'user_id' => $u->id,
            'content' => 'x',
        ]);
        $att = MessageAttachment::create([
            'message_id' => $m->id,
            'file_path' => 'p/'.$round,
            'file_name' => 'n',
            'file_type' => 't',
            'file_size' => 1,
        ]);
        $this->getJson("api/message-attachments/{$att->id}")->assertOk();
    }

    private function dupPostMessageAttachments(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $m = Message::create([
            'conversation_id' => $c->id,
            'user_id' => $u->id,
            'content' => 'x',
        ]);
        $this->postJson('api/message-attachments', [
            'message_id' => $m->id,
            'file_path' => 'manual/'.$round,
            'file_name' => 'n',
            'file_type' => 't',
            'file_size' => 2,
        ])->assertCreated();
    }

    private function dupPutMessageAttachments(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $m = Message::create([
            'conversation_id' => $c->id,
            'user_id' => $u->id,
            'content' => 'x',
        ]);
        $att = MessageAttachment::create([
            'message_id' => $m->id,
            'file_path' => 'p/u'.$round,
            'file_name' => 'old',
            'file_type' => 't',
            'file_size' => 1,
        ]);
        $this->putJson("api/message-attachments/{$att->id}", [
            'file_name' => 'new'.$round,
        ])->assertOk();
    }

    private function dupDeleteMessageAttachments(int $round): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $m = Message::create([
            'conversation_id' => $c->id,
            'user_id' => $u->id,
            'content' => 'x',
        ]);
        $att = MessageAttachment::create([
            'message_id' => $m->id,
            'file_path' => 'p/d'.$round,
            'file_name' => 'n',
            'file_type' => 't',
            'file_size' => 1,
        ]);
        $this->deleteJson("api/message-attachments/{$att->id}")->assertNoContent();
    }

    private function dupPostBroadcastingAuth(int $round): void
    {
        $u = $this->actingFreshUser();
        $this->postJson('/api/broadcasting/auth', [
            'socket_id' => '1.'.$round,
            'channel_name' => 'private-notifications.'.$u->id,
        ])->assertOk();
    }

    private function dupPatchMeDeactivate(int $round): void
    {
        $u = $this->createUser();
        Sanctum::actingAs($u);
        $this->patchJson('api/me/deactivate', ['reason' => 't'.$round])->assertOk();
    }

    private function dupPostRegisterAdmin(int $round): void
    {
        $this->actingFreshAdmin();
        $this->postJson('api/register-admin', [
            'first_name' => 'Ad',
            'last_name' => 'Min'.$round,
            'email' => 'newadm'.$round.substr(bin2hex(random_bytes(8)), 0, 12).'@gmail.com',
            'password' => 'password123',
        ])->assertCreated();
    }

    private function dupGetAdminUsers(int $round): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/users')->assertOk();
    }

    private function dupPatchAdminUsersStatus(int $round): void
    {
        $this->actingFreshAdmin();
        $target = $this->createUser(['email' => "st{$round}@example.com"]);
        $this->patchJson("api/admin/users/{$target->id}/status", [
            'account_status' => 'active',
        ])->assertOk();
    }

    private function dupDeleteAdminUsers(int $round): void
    {
        $this->actingFreshAdmin();
        $target = $this->createUser(['email' => "delu{$round}@example.com"]);
        $this->deleteJson("api/admin/users/{$target->id}")->assertNoContent();
    }

    private function dupPostAdminCategories(int $round): void
    {
        $this->actingFreshAdmin();
        $this->postJson('api/categories', [
            'name' => 'AdminCat'.$round.uniqid(),
            'description' => 'd',
        ])->assertCreated();
    }

    private function dupPutAdminCategories(int $round): void
    {
        $this->actingFreshAdmin();
        $c = Category::factory()->create(['name' => 'PutCat'.$round]);
        $this->putJson("api/categories/{$c->id}", [
            'name' => 'PutCat'.$round.'U',
            'description' => 'e',
        ])->assertOk();
    }

    private function dupDeleteAdminCategories(int $round): void
    {
        $this->actingFreshAdmin();
        $c = Category::factory()->create(['name' => 'DelCat'.$round.uniqid()]);
        $this->deleteJson("api/categories/{$c->id}")->assertOk();
    }

    private function dupGetAdminReports(int $round): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/reports')->assertOk();
    }

    private function dupPatchAdminReportsApprove(int $round): void
    {
        $this->actingFreshAdmin();
        $rep = $this->makePendingRecipeReport($round);
        $this->patchJson("api/admin/reports/{$rep->id}/approve")->assertOk();
    }

    private function dupPatchAdminReportsRemove(int $round): void
    {
        $this->actingFreshAdmin();
        $rep = $this->makePendingRecipeReport($round + 100);
        $this->patchJson("api/admin/reports/{$rep->id}/remove-content")->assertOk();
    }

    private function dupPatchAdminReportsSuspend(int $round): void
    {
        $this->actingFreshAdmin();
        $rep = $this->makePendingUserReport($round);
        $this->patchJson("api/admin/reports/{$rep->id}/suspend-user")->assertOk();
    }

    private function dupPatchAdminReportsUnban(int $round): void
    {
        $this->actingFreshAdmin();
        $rep = $this->makePendingUserReport($round + 200);
        $this->patchJson("api/admin/reports/{$rep->id}/suspend-user")->assertOk();
        $this->patchJson("api/admin/reports/{$rep->id}/unban-user")->assertOk();
    }

    private function dupPatchAdminReportsDismiss(int $round): void
    {
        $this->actingFreshAdmin();
        $rep = $this->makePendingRecipeReport($round + 300);
        $this->patchJson("api/admin/reports/{$rep->id}/dismiss")->assertOk();
    }

    private function dupDeleteAdminReports(int $round): void
    {
        $this->actingFreshAdmin();
        $this->deleteJson('api/admin/reports')->assertOk();
    }

    private function dupGetAdminAuditLogs(int $round): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/audit-logs')->assertOk();
    }

    private function dupGetAdminAuditLogsExport(int $round): void
    {
        $this->actingFreshAdmin();
        $this->get('api/admin/audit-logs/export')->assertOk();
    }

    private function dupGetAdminActivityLogs(int $round): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/activity-logs')->assertOk();
    }

    private function dupGetAdminActivityLogsExport(int $round): void
    {
        $this->actingFreshAdmin();
        $this->get('api/admin/activity-logs/export')->assertOk();
    }

    private function dupGetAdminRecipesRankings(int $round): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/recipes/rankings?window=all')->assertOk();
    }

    private function dupGetAdminStatsOverview(int $round): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/stats/overview')->assertOk();
    }

    private function dupGetAdminStatsUserGrowth(int $round): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/stats/user-growth?range=weekly')->assertOk();
    }

    private function dupGetAdminStatsPostFrequency(int $round): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/stats/post-frequency?range=monthly')->assertOk();
    }

    private function dupGetAdminStatsChatbot(int $round): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/stats/chatbot-interactions?range=monthly')->assertOk();
    }

    private function makePendingRecipeReport(int $salt): Report
    {
        $reporter = $this->createUser(['email' => "repR{$salt}@example.com"]);
        $recipe = $this->createRecipe();

        return Report::create([
            'user_id' => $reporter->id,
            'reportable_type' => Recipe::class,
            'reportable_id' => $recipe->id,
            'reason' => 'test',
            'status' => 'pending',
        ]);
    }

    private function makePendingUserReport(int $salt): Report
    {
        $reporter = $this->createUser(['email' => "repU{$salt}@example.com"]);
        $target = $this->createUser(['email' => "tgtU{$salt}@example.com"]);

        return Report::create([
            'user_id' => $reporter->id,
            'reportable_type' => User::class,
            'reportable_id' => $target->id,
            'reason' => 'test',
            'status' => 'pending',
        ]);
    }
}
