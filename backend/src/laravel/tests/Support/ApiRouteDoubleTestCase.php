<?php

namespace Tests\Support;

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
 * Shared helpers for smoke-testing each API route once per test case.
 */
abstract class ApiRouteDoubleTestCase extends TestCase
{
    use RefreshDatabase;

    abstract protected static function routeKeys(): array;

    public static function routeKeysProvider(): \Generator
    {
        foreach (static::routeKeys() as $key) {
            yield $key => [$key];
        }
    }

    /** @dataProvider routeKeysProvider */
    public function test_each_api_route(string $routeKey): void
    {
        $this->invokeRouteKey($routeKey);
    }

    protected function invokeRouteKey(string $key): void
    {
        match ($key) {
            'POST_register' => $this->dupPostRegister(),
            'POST_login' => $this->dupPostLogin(),
            'POST_forgot_password' => $this->dupPostForgotPassword(),
            'POST_reset_password' => $this->dupPostResetPassword(),
            'POST_login_admin' => $this->dupPostLoginAdmin(),
            'GET_posts' => $this->dupGetPosts(),
            'GET_posts_show' => $this->dupGetPostsShow(),
            'GET_posts_comments' => $this->dupGetPostsComments(),
            'GET_users_show' => $this->dupGetUsersShow(),
            'GET_users_followers' => $this->dupGetUsersFollowers(),
            'GET_users_following' => $this->dupGetUsersFollowing(),
            'GET_categories' => $this->dupGetCategories(),
            'GET_categories_show' => $this->dupGetCategoriesShow(),
            'GET_recipes' => $this->dupGetRecipes(),
            'GET_recipes_rankings' => $this->dupGetRecipesRankings(),
            'GET_recipes_show' => $this->dupGetRecipesShow(),
            'GET_recipes_ratings' => $this->dupGetRecipesRatings(),
            'GET_user' => $this->dupGetUser(),
            'PATCH_user' => $this->dupPatchUser(),
            'POST_user_profile_photo' => $this->dupPostProfilePhoto(),
            'POST_logout' => $this->dupPostLogout(),
            'POST_logout_admin' => $this->dupPostLogoutAdmin(),
            'POST_categories_for_recipe' => $this->dupPostCategoriesForRecipe(),
            'POST_recipes' => $this->dupPostRecipes(),
            'PUT_recipes' => $this->dupPutRecipes(),
            'DELETE_recipes' => $this->dupDeleteRecipes(),
            'POST_recipes_images' => $this->dupPostRecipeImages(),
            'DELETE_recipes_images' => $this->dupDeleteRecipeImages(),
            'PUT_recipes_images_reorder' => $this->dupPutRecipeImagesReorder(),
            'POST_recipes_steps_images' => $this->dupPostRecipeStepImages(),
            'DELETE_recipes_steps_images' => $this->dupDeleteRecipeStepImages(),
            'POST_recipes_like' => $this->dupPostRecipeLike(),
            'DELETE_recipes_like' => $this->dupDeleteRecipeLike(),
            'POST_recipes_report' => $this->dupPostRecipeReport(),
            'POST_recipes_ratings' => $this->dupPostRecipeRatings(),
            'GET_recipes_ratings_me' => $this->dupGetRecipeRatingsMe(),
            'POST_posts' => $this->dupPostPosts(),
            'PUT_posts' => $this->dupPutPosts(),
            'DELETE_posts' => $this->dupDeletePosts(),
            'POST_posts_images' => $this->dupPostPostImages(),
            'DELETE_posts_images' => $this->dupDeletePostImages(),
            'PUT_posts_images_reorder' => $this->dupPutPostImagesReorder(),
            'GET_posts_likes' => $this->dupGetPostLikes(),
            'POST_posts_like' => $this->dupPostPostLike(),
            'DELETE_posts_like' => $this->dupDeletePostLike(),
            'POST_posts_report' => $this->dupPostPostReport(),
            'POST_posts_comments' => $this->dupPostPostComments(),
            'GET_notifications' => $this->dupGetNotifications(),
            'GET_notifications_unread_count' => $this->dupGetNotificationsUnread(),
            'PATCH_notifications_read' => $this->dupPatchNotificationRead(),
            'POST_notifications_read_all' => $this->dupPostNotificationsReadAll(),
            'GET_users_search' => $this->dupGetUsersSearch(),
            'POST_users_follow' => $this->dupPostUsersFollow(),
            'DELETE_users_follow' => $this->dupDeleteUsersFollow(),
            'POST_users_report' => $this->dupPostUsersReport(),
            'POST_recipes_save' => $this->dupPostRecipesSave(),
            'DELETE_recipes_save' => $this->dupDeleteRecipesSave(),
            'GET_saved_recipes' => $this->dupGetSavedRecipes(),
            'GET_recipes_saved' => $this->dupGetRecipesSaved(),
            'GET_meal_plans_export' => $this->dupGetMealPlansExport(),
            'GET_meal_plans' => $this->dupGetMealPlans(),
            'POST_meal_plans' => $this->dupPostMealPlans(),
            'POST_meal_plans_day_skip' => $this->dupPostMealPlansDaySkip(),
            'POST_meal_plans_meal_skip' => $this->dupPostMealPlansMealSkip(),
            'DELETE_meal_plans' => $this->dupDeleteMealPlans(),
            'GET_conversations_assistant' => $this->dupGetConversationsAssistant(),
            'GET_conversations_unread_count' => $this->dupGetConversationsUnreadCount(),
            'GET_conversations' => $this->dupGetConversations(),
            'GET_conversations_show' => $this->dupGetConversationsShow(),
            'POST_conversations' => $this->dupPostConversations(),
            'PUT_conversations' => $this->dupPutConversations(),
            'DELETE_conversations' => $this->dupDeleteConversations(),
            'GET_conversations_messages' => $this->dupGetConversationsMessages(),
            'POST_conversations_messages' => $this->dupPostConversationsMessages(),
            'PATCH_conversations_messages_read' => $this->dupPatchConversationsMessagesRead(),
            'GET_messages' => $this->dupGetMessages(),
            'GET_messages_show' => $this->dupGetMessagesShow(),
            'POST_messages' => $this->dupPostMessages(),
            'PUT_messages' => $this->dupPutMessages(),
            'DELETE_messages' => $this->dupDeleteMessages(),
            'PATCH_messages_read' => $this->dupPatchMessagesRead(),
            'POST_messages_attachments' => $this->dupPostMessagesAttachments(),
            'POST_meal_planner_log' => $this->dupPostMealPlannerLog(),
            'GET_message_attachments' => $this->dupGetMessageAttachments(),
            'GET_message_attachments_show' => $this->dupGetMessageAttachmentsShow(),
            'POST_message_attachments' => $this->dupPostMessageAttachments(),
            'PUT_message_attachments' => $this->dupPutMessageAttachments(),
            'DELETE_message_attachments' => $this->dupDeleteMessageAttachments(),
            'POST_broadcasting_auth' => $this->dupPostBroadcastingAuth(),
            'PATCH_me_deactivate' => $this->dupPatchMeDeactivate(),
            'POST_register_admin' => $this->dupPostRegisterAdmin(),
            'GET_admin_users' => $this->dupGetAdminUsers(),
            'PATCH_admin_users_status' => $this->dupPatchAdminUsersStatus(),
            'DELETE_admin_users' => $this->dupDeleteAdminUsers(),
            'POST_admin_categories' => $this->dupPostAdminCategories(),
            'PUT_admin_categories' => $this->dupPutAdminCategories(),
            'DELETE_admin_categories' => $this->dupDeleteAdminCategories(),
            'GET_admin_reports' => $this->dupGetAdminReports(),
            'PATCH_admin_reports_approve' => $this->dupPatchAdminReportsApprove(),
            'PATCH_admin_reports_remove_content' => $this->dupPatchAdminReportsRemove(),
            'PATCH_admin_reports_suspend_user' => $this->dupPatchAdminReportsSuspend(),
            'PATCH_admin_reports_unban_user' => $this->dupPatchAdminReportsUnban(),
            'PATCH_admin_reports_dismiss' => $this->dupPatchAdminReportsDismiss(),
            'DELETE_admin_reports' => $this->dupDeleteAdminReports(),
            'GET_admin_audit_logs' => $this->dupGetAdminAuditLogs(),
            'GET_admin_audit_logs_export' => $this->dupGetAdminAuditLogsExport(),
            'GET_admin_recipes_rankings' => $this->dupGetAdminRecipesRankings(),
            'GET_admin_stats_overview' => $this->dupGetAdminStatsOverview(),
            'GET_admin_stats_user_growth' => $this->dupGetAdminStatsUserGrowth(),
            'GET_admin_stats_post_frequency' => $this->dupGetAdminStatsPostFrequency(),
            'GET_admin_stats_chatbot_interactions' => $this->dupGetAdminStatsChatbot(),
            default => $this->fail('Unknown route key: '.$key),
        };
    }

    protected function assistantBot(): User
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

    protected function actingFreshUser(): User
    {
        $u = $this->createUser();
        Sanctum::actingAs($u);

        return $u;
    }

    protected function actingFreshAdmin(): User
    {
        $a = $this->createAdmin();
        Sanctum::actingAs($a);

        return $a;
    }

    protected function dupPostRegister(): void
    {
        $email = 'reg'.uniqid('', true).'@example.com';
        $this->postJson('api/register', [
            'first_name' => 'T',
            'last_name' => 'U',
            'email' => $email,
            'password' => 'password123',
            'accepted_terms' => true,
        ])->assertCreated();
    }

    protected function dupPostLogin(): void
    {
        $u = $this->createUser(['email' => 'login'.uniqid('', true).'@example.com', 'password' => Hash::make('password123')]);
        $this->postJson('api/login', [
            'email' => $u->email,
            'password' => 'password123',
        ])->assertOk();
    }

    protected function dupPostForgotPassword(): void
    {
        $email = 'fp'.uniqid('', true).'@example.com';
        $this->createUser(['email' => $email]);
        $this->postJson('api/forgot-password', ['email' => $email])->assertOk();
    }

    protected function dupPostResetPassword(): void
    {
        $email = 'rs'.uniqid('', true).'@example.com';
        $this->createUser(['email' => $email, 'password' => Hash::make('oldpass123')]);
        $code = (string) (600000 + random_int(0, 99999));
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

    protected function dupPostLoginAdmin(): void
    {
        $a = $this->createAdmin(['email' => 'adm'.uniqid('', true).'@example.com', 'password' => Hash::make('adminpass1')]);
        $this->postJson('api/login-admin', [
            'email' => $a->email,
            'password' => 'adminpass1',
        ])->assertOk();
    }

    protected function dupGetPosts(): void
    {
        $u = $this->createUser();
        Post::create([
            'user_id' => $u->id,
            'content' => 'c'.uniqid('', true),
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->getJson('api/posts?per_page=5')->assertOk();
    }

    protected function dupGetPostsShow(): void
    {
        $u = $this->createUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 's'.uniqid('', true),
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->getJson("api/posts/{$p->id}")->assertOk();
    }

    protected function dupGetPostsComments(): void
    {
        $u = $this->createUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 'p'.uniqid('', true),
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $this->getJson("api/posts/{$p->id}/comments")->assertOk();
    }

    protected function dupGetUsersShow(): void
    {
        $u = $this->createUser(['first_name' => 'Pub'.uniqid('', true)]);
        $this->getJson("api/users/{$u->id}")->assertOk();
    }

    protected function dupGetUsersFollowers(): void
    {
        $u = $this->createUser(['first_name' => 'PubF'.uniqid('', true)]);
        $follower = $this->createUser(['email' => 'flw'.uniqid('', true).'@example.com']);
        $follower->following()->attach($u->id);
        $this->getJson("api/users/{$u->id}/followers")->assertOk();
    }

    protected function dupGetUsersFollowing(): void
    {
        $u = $this->createUser(['first_name' => 'PubG'.uniqid('', true)]);
        $followed = $this->createUser(['email' => 'fd'.uniqid('', true).'@example.com']);
        $u->following()->attach($followed->id);
        $this->getJson("api/users/{$u->id}/following")->assertOk();
    }

    protected function dupGetCategories(): void
    {
        Category::factory()->create(['name' => 'CatDup'.uniqid('', true)]);
        $this->getJson('api/categories')->assertOk();
    }

    protected function dupGetCategoriesShow(): void
    {
        $c = Category::factory()->create(['name' => 'ShowCat'.uniqid('', true)]);
        $this->getJson("api/categories/{$c->id}")->assertOk();
    }

    protected function dupGetRecipes(): void
    {
        $this->createRecipe(['title' => 'R'.uniqid('', true)]);
        $this->getJson('api/recipes?per_page=3')->assertOk();
    }

    protected function dupGetRecipesRankings(): void
    {
        $this->getJson('api/recipes/rankings?window=all&mode=combined')->assertOk();
    }

    protected function dupGetRecipesShow(): void
    {
        $r = $this->createRecipe(['title' => 'Show'.uniqid('', true)]);
        $this->getJson("api/recipes/{$r->id}")->assertOk();
    }

    protected function dupGetRecipesRatings(): void
    {
        $r = $this->createRecipe();
        $u = $this->createUser();
        $r->ratings()->create(['user_id' => $u->id, 'rating' => 4, 'comment' => 'x'.uniqid('', true)]);
        $this->getJson("api/recipes/{$r->id}/ratings")->assertOk();
    }

    protected function dupGetUser(): void
    {
        $u = $this->actingFreshUser();
        $this->getJson('api/user')->assertOk()->assertJsonPath('id', $u->id);
    }

    protected function dupPatchUser(): void
    {
        $u = $this->actingFreshUser();
        $this->patchJson('api/user', [
            'first_name' => 'N'.uniqid('', true),
            'last_name' => 'L'.uniqid('', true),
        ])->assertOk();
    }

    protected function dupPostProfilePhoto(): void
    {
        Storage::fake('public');
        $this->actingFreshUser();
        $this->postJson('api/user/profile-photo', [
            'image' => UploadedFile::fake()->create('p'.uniqid('', true).'.jpg', 50, 'image/jpeg'),
        ])->assertCreated();
    }

    protected function dupPostLogout(): void
    {
        $u = $this->createUser();
        $u->createToken('t'.uniqid('', true));
        Sanctum::actingAs($u);
        $this->postJson('api/logout')->assertOk();
    }

    protected function dupPostLogoutAdmin(): void
    {
        $a = $this->createAdmin();
        $a->createToken('adm'.uniqid('', true));
        Sanctum::actingAs($a);
        $this->postJson('api/logout-admin')->assertOk();
    }

    protected function dupPostCategoriesForRecipe(): void
    {
        $this->actingFreshUser();
        $this->postJson('api/categories/for-recipe', [
            'name' => 'ForRecipe'.uniqid('', true).uniqid(),
        ])->assertSuccessful();
    }

    protected function dupPostRecipes(): void
    {
        $u = $this->actingFreshUser();
        $cat = Category::factory()->create();
        $this->postJson('api/recipes', [
            'category_id' => $cat->id,
            'title' => 'NewR'.uniqid('', true).uniqid(),
            'description' => 'd',
            'instructions' => 'do it',
            'prep_time' => 10,
        ])->assertCreated();
    }

    protected function dupPutRecipes(): void
    {
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id, 'title' => 'T'.uniqid('', true)]);
        $this->putJson("api/recipes/{$r->id}", [
            'title' => 'U'.uniqid('', true),
            'instructions' => 'still good',
            'prep_time' => 12,
        ])->assertOk();
    }

    protected function dupDeleteRecipes(): void
    {
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id]);
        $this->deleteJson("api/recipes/{$r->id}")->assertOk();
    }

    protected function dupPostRecipeImages(): void
    {
        Storage::fake('public');
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id]);
        $this->post("api/recipes/{$r->id}/images", [
            'image' => UploadedFile::fake()->create('ri'.uniqid('', true).'.jpg', 50, 'image/jpeg'),
        ])->assertCreated();
    }

    protected function dupDeleteRecipeImages(): void
    {
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id]);
        $img = $r->images()->create(['path' => 'recipes/d'.uniqid('', true).'.jpg', 'sort_order' => 0]);
        $this->deleteJson("api/recipes/{$r->id}/images/{$img->id}")->assertOk();
    }

    protected function dupPutRecipeImagesReorder(): void
    {
        $u = $this->actingFreshUser();
        $r = Recipe::factory()->withoutIngredients()->create(['user_id' => $u->id]);
        $a = $r->images()->create(['path' => 'r/a'.uniqid('', true).'.jpg', 'sort_order' => 0]);
        $b = $r->images()->create(['path' => 'r/b'.uniqid('', true).'.jpg', 'sort_order' => 1]);
        $this->putJson("api/recipes/{$r->id}/images/reorder", [
            'image_ids' => [$b->id, $a->id],
        ])->assertOk();
    }

    protected function dupPostRecipeStepImages(): void
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
            'image' => UploadedFile::fake()->create('st'.uniqid('', true).'.jpg', 50, 'image/jpeg'),
        ])->assertCreated();
    }

    protected function dupDeleteRecipeStepImages(): void
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
        $img = $step->images()->create(['path' => 'steps/x'.uniqid('', true).'.jpg', 'sort_order' => 0]);
        $this->deleteJson("api/recipes/{$r->id}/steps/{$step->id}/images/{$img->id}")->assertOk();
    }

    protected function dupPostRecipeLike(): void
    {
        $u = $this->actingFreshUser();
        $owner = $this->createUser();
        $r = $this->createRecipe(['user_id' => $owner->id]);
        $this->postJson("api/recipes/{$r->id}/like")->assertCreated();
    }

    protected function dupDeleteRecipeLike(): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $this->postJson("api/recipes/{$r->id}/like")->assertCreated();
        $this->deleteJson("api/recipes/{$r->id}/like")->assertOk();
    }

    protected function dupPostRecipeReport(): void
    {
        $this->createAdmin();
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $this->postJson("api/recipes/{$r->id}/report", [
            'reason' => 'r'.uniqid('', true),
        ])->assertCreated();
    }

    protected function dupPostRecipeRatings(): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $this->postJson("api/recipes/{$r->id}/ratings", [
            'rating' => 4,
            'comment' => 'c'.uniqid('', true),
        ])->assertSuccessful();
    }

    protected function dupGetRecipeRatingsMe(): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $r->ratings()->create(['user_id' => $u->id, 'rating' => 3, 'comment' => null]);
        $this->getJson("api/recipes/{$r->id}/ratings/me")->assertOk();
    }

    protected function dupPostPosts(): void
    {
        $this->actingFreshUser();
        $this->postJson('api/posts', [
            'content' => 'Post body '.uniqid('', true),
        ])->assertCreated();
    }

    protected function dupPutPosts(): void
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
            'content' => 'updated '.uniqid('', true),
        ])->assertOk();
    }

    protected function dupDeletePosts(): void
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

    protected function dupPostPostImages(): void
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
            'image' => UploadedFile::fake()->create('pi'.uniqid('', true).'.jpg', 50, 'image/jpeg'),
        ])->assertCreated();
    }

    protected function dupDeletePostImages(): void
    {
        $u = $this->actingFreshUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 'i',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $img = $p->images()->create(['path' => 'posts/dp'.uniqid('', true).'.jpg', 'sort_order' => 0]);
        $this->deleteJson("api/posts/{$p->id}/images/{$img->id}")->assertOk();
    }

    protected function dupPutPostImagesReorder(): void
    {
        $u = $this->actingFreshUser();
        $p = Post::create([
            'user_id' => $u->id,
            'content' => 'i',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $a = $p->images()->create(['path' => 'p/a'.uniqid('', true).'.jpg', 'sort_order' => 0]);
        $b = $p->images()->create(['path' => 'p/b'.uniqid('', true).'.jpg', 'sort_order' => 1]);
        $this->putJson("api/posts/{$p->id}/images/reorder", [
            'image_ids' => [$b->id, $a->id],
        ])->assertOk();
    }

    protected function dupGetPostLikes(): void
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

    protected function dupPostPostLike(): void
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

    protected function dupDeletePostLike(): void
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

    protected function dupPostPostReport(): void
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
        $this->postJson("api/posts/{$p->id}/report", ['reason' => 'x'.uniqid('', true)])->assertCreated();
    }

    protected function dupPostPostComments(): void
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
            'comment' => 'hi '.uniqid('', true),
        ])->assertCreated();
    }

    protected function dupGetNotifications(): void
    {
        $this->actingFreshUser();
        $this->getJson('api/notifications')->assertOk();
    }

    protected function dupGetNotificationsUnread(): void
    {
        $this->actingFreshUser();
        $this->getJson('api/notifications/unread-count')->assertOk();
    }

    protected function dupPatchNotificationRead(): void
    {
        $u = $this->actingFreshUser();
        $id = (string) Str::uuid();
        DB::table('notifications')->insert([
            'id' => $id,
            'type' => 'App\\Notifications\\NewMessageNotification',
            'notifiable_type' => User::class,
            'notifiable_id' => $u->id,
            'data' => json_encode(['type' => 'new_message', 'message' => 'm'.uniqid('', true)]),
            'read_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $this->patchJson("api/notifications/{$id}/read")->assertOk();
    }

    protected function dupPostNotificationsReadAll(): void
    {
        $this->actingFreshUser();
        $this->postJson('api/notifications/read-all')->assertOk();
    }

    protected function dupGetUsersSearch(): void
    {
        $this->createUser(['first_name' => 'Searchable'.uniqid('', true), 'last_name' => 'X']);
        $this->actingFreshUser();
        $this->getJson('api/users/search?q=Searchable')->assertOk();
    }

    protected function dupPostUsersFollow(): void
    {
        $u = $this->actingFreshUser();
        $other = $this->createUser(['email' => 'fol'.uniqid('', true).'@example.com']);
        $this->postJson("api/users/{$other->id}/follow")->assertCreated();
    }

    protected function dupDeleteUsersFollow(): void
    {
        $u = $this->actingFreshUser();
        $other = $this->createUser(['email' => 'uf'.uniqid('', true).'@example.com']);
        $u->following()->attach($other->id);
        $this->deleteJson("api/users/{$other->id}/follow")->assertOk();
    }

    protected function dupPostUsersReport(): void
    {
        $this->createAdmin();
        $u = $this->actingFreshUser();
        $other = $this->createUser(['email' => 'rep'.uniqid('', true).'@example.com']);
        $this->postJson("api/users/{$other->id}/report", [
            'reason' => 'bad'.uniqid('', true),
        ])->assertCreated();
    }

    protected function dupPostRecipesSave(): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $this->postJson("api/recipes/{$r->id}/save")->assertCreated();
    }

    protected function dupDeleteRecipesSave(): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $u->savedRecipes()->syncWithoutDetaching([$r->id]);
        $this->deleteJson("api/recipes/{$r->id}/save")->assertOk();
    }

    protected function dupGetSavedRecipes(): void
    {
        $this->actingFreshUser();
        $this->getJson('api/saved-recipes')->assertOk();
    }

    protected function dupGetRecipesSaved(): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $this->getJson("api/recipes/{$r->id}/saved")->assertOk();
    }

    protected function dupGetMealPlansExport(): void
    {
        $u = $this->actingFreshUser();
        $ws = now()->startOfWeek()->toDateString();
        $this->getJson('api/meal-plans/export?week_start='.$ws)->assertOk();
    }

    protected function dupGetMealPlans(): void
    {
        $this->actingFreshUser();
        $ws = now()->startOfWeek()->toDateString();
        $this->getJson('api/meal-plans?week_start='.$ws)->assertOk();
    }

    protected function dupPostMealPlans(): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $date = now()->addDays(30 + random_int(0, 30))->toDateString();
        $this->postJson('api/meal-plans', [
            'recipe_id' => $r->id,
            'planned_date' => $date,
            'meal_slot' => 'dinner',
        ])->assertSuccessful();
    }

    protected function dupPostMealPlansDaySkip(): void
    {
        $this->actingFreshUser();
        $d = now()->addDays(40 + random_int(0, 30))->toDateString();
        $this->postJson('api/meal-plans/day-skip', [
            'planned_date' => $d,
            'did_not_eat' => true,
        ])->assertOk();
    }

    protected function dupPostMealPlansMealSkip(): void
    {
        $this->actingFreshUser();
        $d = now()->addDays(50 + random_int(0, 30))->toDateString();
        $this->postJson('api/meal-plans/meal-skip', [
            'planned_date' => $d,
            'meal_slot' => 'breakfast',
            'skipped' => true,
        ])->assertOk();
    }

    protected function dupDeleteMealPlans(): void
    {
        $u = $this->actingFreshUser();
        $r = $this->createRecipe();
        $plan = MealPlan::create([
            'user_id' => $u->id,
            'recipe_id' => $r->id,
            'planned_date' => now()->addDays(60 + random_int(0, 30))->toDateString(),
            'meal_slot' => 'lunch',
        ]);
        $this->deleteJson("api/meal-plans/{$plan->id}")->assertOk();
    }

    protected function dupGetConversationsAssistant(): void
    {
        $this->assistantBot();
        $this->actingFreshUser();
        $this->getJson('api/conversations/assistant')->assertOk();
    }

    protected function dupGetConversationsUnreadCount(): void
    {
        $this->actingFreshUser();
        $this->getJson('api/conversations/unread-count')->assertOk();
    }

    protected function dupGetConversations(): void
    {
        $this->actingFreshUser();
        $this->getJson('api/conversations')->assertOk();
    }

    protected function dupGetConversationsShow(): void
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

    protected function dupPostConversations(): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser(['email' => 'conv'.uniqid('', true).'@example.com']);
        $this->postJson('api/conversations', ['user_id' => $o->id])->assertCreated();
    }

    protected function dupPutConversations(): void
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

    protected function dupDeleteConversations(): void
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

    protected function dupGetConversationsMessages(): void
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

    protected function dupPostConversationsMessages(): void
    {
        $u = $this->actingFreshUser();
        $o = $this->createUser();
        $c = Conversation::create([
            'user1_id' => min($u->id, $o->id),
            'user2_id' => max($u->id, $o->id),
            'last_message_at' => now(),
        ]);
        $this->postJson("api/conversations/{$c->id}/messages", [
            'content' => 'm'.uniqid('', true),
        ])->assertCreated();
    }

    protected function dupPatchConversationsMessagesRead(): void
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

    protected function dupGetMessages(): void
    {
        $this->dupPostConversationsMessages();
        $this->getJson('api/messages')->assertOk();
    }

    protected function dupGetMessagesShow(): void
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
            'content' => 'show'.uniqid('', true),
        ]);
        $this->getJson("api/messages/{$m->id}")->assertOk();
    }

    protected function dupPostMessages(): void
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
            'content' => 'legacy '.uniqid('', true),
        ])->assertCreated();
    }

    protected function dupPutMessages(): void
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
        $this->putJson("api/messages/{$m->id}", ['content' => 'new '.uniqid('', true)])->assertOk();
    }

    protected function dupDeleteMessages(): void
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

    protected function dupPatchMessagesRead(): void
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

    protected function dupPostMessagesAttachments(): void
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
            'file' => UploadedFile::fake()->create('f'.uniqid('', true).'.jpg', 50, 'image/jpeg'),
        ])->assertCreated();
    }

    protected function dupPostMealPlannerLog(): void
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

    protected function dupGetMessageAttachments(): void
    {
        $this->actingFreshUser();
        $this->getJson('api/message-attachments')->assertOk();
    }

    protected function dupGetMessageAttachmentsShow(): void
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
            'file_path' => 'p/'.uniqid('', true),
            'file_name' => 'n',
            'file_type' => 't',
            'file_size' => 1,
        ]);
        $this->getJson("api/message-attachments/{$att->id}")->assertOk();
    }

    protected function dupPostMessageAttachments(): void
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
            'file_path' => 'manual/'.uniqid('', true),
            'file_name' => 'n',
            'file_type' => 't',
            'file_size' => 2,
        ])->assertCreated();
    }

    protected function dupPutMessageAttachments(): void
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
            'file_path' => 'p/u'.uniqid('', true),
            'file_name' => 'old',
            'file_type' => 't',
            'file_size' => 1,
        ]);
        $this->putJson("api/message-attachments/{$att->id}", [
            'file_name' => 'new'.uniqid('', true),
        ])->assertOk();
    }

    protected function dupDeleteMessageAttachments(): void
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
            'file_path' => 'p/d'.uniqid('', true),
            'file_name' => 'n',
            'file_type' => 't',
            'file_size' => 1,
        ]);
        $this->deleteJson("api/message-attachments/{$att->id}")->assertNoContent();
    }

    protected function dupPostBroadcastingAuth(): void
    {
        $u = $this->actingFreshUser();
        $this->postJson('/api/broadcasting/auth', [
            'socket_id' => '1.'.random_int(100000, 999999),
            'channel_name' => 'private-notifications.'.$u->id,
        ])->assertOk();
    }

    protected function dupPatchMeDeactivate(): void
    {
        $u = $this->createUser();
        Sanctum::actingAs($u);
        $this->patchJson('api/me/deactivate', ['reason' => 't'.uniqid('', true)])->assertOk();
    }

    protected function dupPostRegisterAdmin(): void
    {
        $this->actingFreshAdmin();
        $this->postJson('api/register-admin', [
            'first_name' => 'Ad',
            'last_name' => 'Min'.uniqid('', true),
            'email' => 'newadm'.uniqid('', true).substr(bin2hex(random_bytes(8)), 0, 12).'@gmail.com',
            'password' => 'password123',
        ])->assertCreated();
    }

    protected function dupGetAdminUsers(): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/users')->assertOk();
    }

    protected function dupPatchAdminUsersStatus(): void
    {
        $this->actingFreshAdmin();
        $target = $this->createUser(['email' => 'st'.uniqid('', true).'@example.com']);
        $this->patchJson("api/admin/users/{$target->id}/status", [
            'account_status' => 'active',
        ])->assertOk();
    }

    protected function dupDeleteAdminUsers(): void
    {
        $this->actingFreshAdmin();
        $target = $this->createUser(['email' => 'delu'.uniqid('', true).'@example.com']);
        $this->deleteJson("api/admin/users/{$target->id}")->assertNoContent();
    }

    protected function dupPostAdminCategories(): void
    {
        $this->actingFreshAdmin();
        $this->postJson('api/categories', [
            'name' => 'AdminCat'.uniqid('', true).uniqid(),
            'description' => 'd',
        ])->assertCreated();
    }

    protected function dupPutAdminCategories(): void
    {
        $this->actingFreshAdmin();
        $c = Category::factory()->create(['name' => 'PutCat'.uniqid('', true)]);
        $this->putJson("api/categories/{$c->id}", [
            'name' => 'PutCat'.uniqid('', true).'U',
            'description' => 'e',
        ])->assertOk();
    }

    protected function dupDeleteAdminCategories(): void
    {
        $this->actingFreshAdmin();
        $c = Category::factory()->create(['name' => 'DelCat'.uniqid('', true).uniqid()]);
        $this->deleteJson("api/categories/{$c->id}")->assertOk();
    }

    protected function dupGetAdminReports(): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/reports')->assertOk();
    }

    protected function dupPatchAdminReportsApprove(): void
    {
        $this->actingFreshAdmin();
        $rep = $this->makePendingRecipeReport(random_int(0, 99999));
        $this->patchJson("api/admin/reports/{$rep->id}/approve")->assertOk();
    }

    protected function dupPatchAdminReportsRemove(): void
    {
        $this->actingFreshAdmin();
        $rep = $this->makePendingRecipeReport(random_int(0, 30) + 100);
        $this->patchJson("api/admin/reports/{$rep->id}/remove-content")->assertOk();
    }

    protected function dupPatchAdminReportsSuspend(): void
    {
        $this->actingFreshAdmin();
        $rep = $this->makePendingUserReport(random_int(0, 99999));
        $this->patchJson("api/admin/reports/{$rep->id}/suspend-user")->assertOk();
    }

    protected function dupPatchAdminReportsUnban(): void
    {
        $this->actingFreshAdmin();
        $rep = $this->makePendingUserReport(random_int(0, 30) + 200);
        $this->patchJson("api/admin/reports/{$rep->id}/suspend-user")->assertOk();
        $this->patchJson("api/admin/reports/{$rep->id}/unban-user")->assertOk();
    }

    protected function dupPatchAdminReportsDismiss(): void
    {
        $this->actingFreshAdmin();
        $rep = $this->makePendingRecipeReport(random_int(0, 30) + 300);
        $this->patchJson("api/admin/reports/{$rep->id}/dismiss")->assertOk();
    }

    protected function dupDeleteAdminReports(): void
    {
        $this->actingFreshAdmin();
        $this->deleteJson('api/admin/reports')->assertOk();
    }

    protected function dupGetAdminAuditLogs(): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/audit-logs')->assertOk();
    }

    protected function dupGetAdminAuditLogsExport(): void
    {
        $this->actingFreshAdmin();
        $this->get('api/admin/audit-logs/export')->assertOk();
    }

    protected function dupGetAdminRecipesRankings(): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/recipes/rankings?window=all')->assertOk();
    }

    protected function dupGetAdminStatsOverview(): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/stats/overview')->assertOk();
    }

    protected function dupGetAdminStatsUserGrowth(): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/stats/user-growth?range=weekly')->assertOk();
    }

    protected function dupGetAdminStatsPostFrequency(): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/stats/post-frequency?range=monthly')->assertOk();
    }

    protected function dupGetAdminStatsChatbot(): void
    {
        $this->actingFreshAdmin();
        $this->getJson('api/admin/stats/chatbot-interactions?range=monthly')->assertOk();
    }

    protected function makePendingRecipeReport(int $salt): Report
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

    protected function makePendingUserReport(int $salt): Report
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
