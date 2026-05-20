<?php

namespace Tests\Feature;

use App\Models\ActivityLog;
use App\Models\Category;
use App\Models\Conversation;
use App\Models\Image;
use App\Models\Ingredient;
use App\Models\MealPlan;
use App\Models\MealPlanDaySkip;
use App\Models\MealPlanMealSkip;
use App\Models\Message;
use App\Models\MessageAttachment;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\Recipe;
use App\Models\RecipeIngredient;
use App\Models\RecipeRating;
use App\Models\RecipeStep;
use App\Models\RecipeView;
use App\Models\Report;
use App\Models\SavedRecipe;
use App\Models\User;
use App\Models\Vote;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ModelLifecycleFeatureTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_model_persists_from_factory(): void
    {
        $user = $this->createUser(['email' => 'persist@example.com']);

        $this->assertDatabaseHas('users', ['email' => 'persist@example.com']);
        $this->assertSame('persist@example.com', $user->fresh()->email);
    }

    public function test_user_model_updates_scalar_attributes(): void
    {
        $user = $this->createUser(['first_name' => 'A']);

        $user->update(['first_name' => 'B']);

        $this->assertSame('B', $user->fresh()->first_name);
    }

    public function test_user_model_exposes_posts_relation(): void
    {
        $user = $this->createUser();
        Post::create([
            'user_id' => $user->id,
            'content' => 'c',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $this->assertCount(1, $user->fresh()->posts);
    }

    public function test_user_model_can_issue_api_token(): void
    {
        $user = $this->createUser();
        $token = $user->createToken('t')->plainTextToken;

        $this->assertNotEmpty($token);
        $this->assertSame(1, $user->tokens()->count());
    }

    public function test_activity_log_model_persists(): void
    {
        $user = $this->createUser();
        $log = ActivityLog::create([
            'user_id' => $user->id,
            'category' => 'auth',
            'action' => 'test',
            'description' => 'd',
        ]);

        $this->assertDatabaseHas('activity_logs', ['id' => $log->id, 'action' => 'test']);
    }

    public function test_activity_log_model_links_to_user(): void
    {
        $user = $this->createUser();
        $log = ActivityLog::create([
            'user_id' => $user->id,
            'category' => 'auth',
            'action' => 'link',
            'description' => 'd',
        ]);

        $this->assertTrue($log->user->is($user));
    }

    public function test_activity_log_model_updates_description(): void
    {
        $user = $this->createUser();
        $log = ActivityLog::create([
            'user_id' => $user->id,
            'category' => 'auth',
            'action' => 'u',
            'description' => 'old',
        ]);

        $log->update(['description' => 'new']);

        $this->assertSame('new', $log->fresh()->description);
    }

    public function test_activity_log_model_can_be_deleted(): void
    {
        $user = $this->createUser();
        $log = ActivityLog::create([
            'user_id' => $user->id,
            'category' => 'auth',
            'action' => 'del',
            'description' => 'd',
        ]);

        $log->delete();

        $this->assertDatabaseMissing('activity_logs', ['id' => $log->id]);
    }

    public function test_recipe_rating_model_persists(): void
    {
        $recipe = $this->createRecipe();
        $user = $this->createUser();
        $rating = RecipeRating::create([
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'rating' => 4,
            'comment' => 'ok',
        ]);

        $this->assertDatabaseHas('recipe_ratings', ['id' => $rating->id, 'rating' => 4]);
    }

    public function test_recipe_rating_model_belongs_to_recipe(): void
    {
        $recipe = $this->createRecipe();
        $user = $this->createUser();
        $rating = RecipeRating::create([
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'rating' => 3,
        ]);

        $this->assertTrue($rating->recipe->is($recipe));
    }

    public function test_recipe_rating_model_updates_comment(): void
    {
        $recipe = $this->createRecipe();
        $user = $this->createUser();
        $rating = RecipeRating::create([
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'rating' => 3,
            'comment' => 'a',
        ]);

        $rating->update(['comment' => 'b']);

        $this->assertSame('b', $rating->fresh()->comment);
    }

    public function test_recipe_rating_model_can_be_deleted(): void
    {
        $recipe = $this->createRecipe();
        $user = $this->createUser();
        $rating = RecipeRating::create([
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'rating' => 2,
        ]);

        $rating->delete();

        $this->assertDatabaseMissing('recipe_ratings', ['id' => $rating->id]);
    }

    public function test_message_attachment_model_persists(): void
    {
        $u1 = $this->createUser();
        $u2 = $this->createUser();
        $conv = Conversation::create([
            'user1_id' => $u1->id,
            'user2_id' => $u2->id,
            'last_message_at' => now(),
        ]);
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'user_id' => $u1->id,
            'content' => 'hi',
        ]);
        $att = MessageAttachment::create([
            'message_id' => $msg->id,
            'file_path' => 'a/b.bin',
            'file_name' => 'b.bin',
            'file_type' => 'application/octet-stream',
            'file_size' => 10,
        ]);

        $this->assertDatabaseHas('message_attachments', ['id' => $att->id]);
    }

    public function test_message_attachment_model_belongs_to_message(): void
    {
        $u1 = $this->createUser();
        $u2 = $this->createUser();
        $conv = Conversation::create([
            'user1_id' => $u1->id,
            'user2_id' => $u2->id,
            'last_message_at' => now(),
        ]);
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'user_id' => $u1->id,
            'content' => 'm',
        ]);
        $att = MessageAttachment::create([
            'message_id' => $msg->id,
            'file_path' => 'p',
            'file_name' => 'n',
            'file_type' => 't',
            'file_size' => 1,
        ]);

        $this->assertTrue($att->message->is($msg));
    }

    public function test_message_attachment_model_updates_file_name(): void
    {
        $u1 = $this->createUser();
        $u2 = $this->createUser();
        $conv = Conversation::create([
            'user1_id' => $u1->id,
            'user2_id' => $u2->id,
            'last_message_at' => now(),
        ]);
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'user_id' => $u1->id,
            'content' => 'm',
        ]);
        $att = MessageAttachment::create([
            'message_id' => $msg->id,
            'file_path' => 'p',
            'file_name' => 'old',
            'file_type' => 't',
            'file_size' => 1,
        ]);

        $att->update(['file_name' => 'new']);

        $this->assertSame('new', $att->fresh()->file_name);
    }

    public function test_message_attachment_model_can_be_deleted(): void
    {
        $u1 = $this->createUser();
        $u2 = $this->createUser();
        $conv = Conversation::create([
            'user1_id' => $u1->id,
            'user2_id' => $u2->id,
            'last_message_at' => now(),
        ]);
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'user_id' => $u1->id,
            'content' => 'm',
        ]);
        $att = MessageAttachment::create([
            'message_id' => $msg->id,
            'file_path' => 'p',
            'file_name' => 'n',
            'file_type' => 't',
            'file_size' => 1,
        ]);

        $att->delete();

        $this->assertDatabaseMissing('message_attachments', ['id' => $att->id]);
    }

    public function test_report_model_persists(): void
    {
        $reporter = $this->createUser();
        $recipe = $this->createRecipe();
        $report = Report::create([
            'user_id' => $reporter->id,
            'reportable_type' => Recipe::class,
            'reportable_id' => $recipe->id,
            'reason' => 'r',
        ]);

        $this->assertDatabaseHas('reports', ['id' => $report->id]);
    }

    public function test_report_model_morphs_to_recipe(): void
    {
        $reporter = $this->createUser();
        $recipe = $this->createRecipe();
        $report = Report::create([
            'user_id' => $reporter->id,
            'reportable_type' => Recipe::class,
            'reportable_id' => $recipe->id,
            'reason' => 'r',
        ]);

        $this->assertInstanceOf(Recipe::class, $report->reportable);
    }

    public function test_report_model_updates_status(): void
    {
        $reporter = $this->createUser();
        $recipe = $this->createRecipe();
        $report = Report::create([
            'user_id' => $reporter->id,
            'reportable_type' => Recipe::class,
            'reportable_id' => $recipe->id,
            'reason' => 'r',
        ]);

        $report->update(['status' => 'approved']);

        $this->assertSame('approved', $report->fresh()->status);
    }

    public function test_report_model_can_be_deleted(): void
    {
        $reporter = $this->createUser();
        $recipe = $this->createRecipe();
        $report = Report::create([
            'user_id' => $reporter->id,
            'reportable_type' => Recipe::class,
            'reportable_id' => $recipe->id,
            'reason' => 'r',
        ]);

        $report->delete();

        $this->assertDatabaseMissing('reports', ['id' => $report->id]);
    }

    public function test_vote_model_persists(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $vote = Vote::create([
            'user_id' => $user->id,
            'votable_type' => Recipe::class,
            'votable_id' => $recipe->id,
            'vote' => true,
        ]);

        $this->assertDatabaseHas('votes', ['id' => $vote->id]);
    }

    public function test_vote_model_morphs_to_recipe(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $vote = Vote::create([
            'user_id' => $user->id,
            'votable_type' => Recipe::class,
            'votable_id' => $recipe->id,
            'vote' => true,
        ]);

        $this->assertInstanceOf(Recipe::class, $vote->votable);
    }

    public function test_vote_model_updates_flag(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $vote = Vote::create([
            'user_id' => $user->id,
            'votable_type' => Recipe::class,
            'votable_id' => $recipe->id,
            'vote' => true,
        ]);

        $vote->update(['vote' => false]);

        $this->assertFalse((bool) $vote->fresh()->vote);
    }

    public function test_vote_model_can_be_deleted(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $vote = Vote::create([
            'user_id' => $user->id,
            'votable_type' => Recipe::class,
            'votable_id' => $recipe->id,
            'vote' => true,
        ]);

        $vote->delete();

        $this->assertDatabaseMissing('votes', ['id' => $vote->id]);
    }

    public function test_saved_recipe_model_persists(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $row = SavedRecipe::create(['user_id' => $user->id, 'recipe_id' => $recipe->id]);

        $this->assertDatabaseHas('saved_recipes', ['id' => $row->id]);
    }

    public function test_saved_recipe_model_links_user_and_recipe(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $row = SavedRecipe::create(['user_id' => $user->id, 'recipe_id' => $recipe->id]);

        $this->assertTrue($row->user->is($user));
        $this->assertTrue($row->recipe->is($recipe));
    }

    public function test_saved_recipe_model_first_or_create_is_stable(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $a = SavedRecipe::firstOrCreate(['user_id' => $user->id, 'recipe_id' => $recipe->id]);
        $b = SavedRecipe::firstOrCreate(['user_id' => $user->id, 'recipe_id' => $recipe->id]);

        $this->assertSame($a->id, $b->id);
    }

    public function test_saved_recipe_model_can_be_deleted(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $row = SavedRecipe::create(['user_id' => $user->id, 'recipe_id' => $recipe->id]);

        $row->delete();

        $this->assertDatabaseMissing('saved_recipes', ['id' => $row->id]);
    }

    public function test_recipe_step_model_persists(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $step = RecipeStep::create([
            'recipe_id' => $recipe->id,
            'sort_order' => 0,
            'title' => 'T',
            'instructions' => 'I',
            'prep_time_minutes' => 2,
        ]);

        $this->assertDatabaseHas('recipe_steps', ['id' => $step->id]);
    }

    public function test_recipe_step_model_belongs_to_recipe(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $step = RecipeStep::create([
            'recipe_id' => $recipe->id,
            'sort_order' => 0,
            'title' => 'T',
            'instructions' => 'I',
            'prep_time_minutes' => 2,
        ]);

        $this->assertTrue($step->recipe->is($recipe));
    }

    public function test_recipe_step_model_updates_title(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $step = RecipeStep::create([
            'recipe_id' => $recipe->id,
            'sort_order' => 0,
            'title' => 'Old',
            'instructions' => 'I',
            'prep_time_minutes' => 2,
        ]);

        $step->update(['title' => 'New']);

        $this->assertSame('New', $step->fresh()->title);
    }

    public function test_recipe_step_model_can_be_deleted(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $step = RecipeStep::create([
            'recipe_id' => $recipe->id,
            'sort_order' => 0,
            'title' => 'T',
            'instructions' => 'I',
            'prep_time_minutes' => 2,
        ]);

        $step->delete();

        $this->assertDatabaseMissing('recipe_steps', ['id' => $step->id]);
    }

    public function test_recipe_ingredient_model_persists(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $ing = Ingredient::firstOrCreate(['name' => 'SaltModelX']);
        $pivot = RecipeIngredient::create([
            'recipe_id' => $recipe->id,
            'ingredient_id' => $ing->id,
        ]);

        $this->assertDatabaseHas('recipe_ingredients', ['id' => $pivot->id]);
    }

    public function test_recipe_ingredient_model_links_ingredient(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $ing = Ingredient::firstOrCreate(['name' => 'PepperModelX']);
        $pivot = RecipeIngredient::create([
            'recipe_id' => $recipe->id,
            'ingredient_id' => $ing->id,
        ]);

        $this->assertTrue($pivot->ingredient->is($ing));
    }

    public function test_recipe_ingredient_model_updates_timestamps(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $ing = Ingredient::firstOrCreate(['name' => 'SugarModelX']);
        $pivot = RecipeIngredient::create([
            'recipe_id' => $recipe->id,
            'ingredient_id' => $ing->id,
        ]);

        $before = $pivot->fresh()->updated_at;

        $this->travel(2)->seconds();
        $pivot->touch();

        $this->assertTrue($pivot->fresh()->updated_at->gt($before));
    }

    public function test_recipe_ingredient_model_can_be_deleted(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $ing = Ingredient::firstOrCreate(['name' => 'OilModelX']);
        $pivot = RecipeIngredient::create([
            'recipe_id' => $recipe->id,
            'ingredient_id' => $ing->id,
        ]);

        $pivot->delete();

        $this->assertDatabaseMissing('recipe_ingredients', ['id' => $pivot->id]);
    }

    public function test_meal_plan_model_persists(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $date = now()->addDay()->toDateString();
        $plan = MealPlan::create([
            'user_id' => $user->id,
            'recipe_id' => $recipe->id,
            'planned_date' => $date,
            'meal_slot' => 'lunch',
        ]);

        $this->assertDatabaseHas('meal_plans', ['id' => $plan->id]);
    }

    public function test_meal_plan_model_belongs_to_recipe(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $date = now()->addDays(2)->toDateString();
        $plan = MealPlan::create([
            'user_id' => $user->id,
            'recipe_id' => $recipe->id,
            'planned_date' => $date,
            'meal_slot' => 'dinner',
        ]);

        $this->assertTrue($plan->recipe->is($recipe));
    }

    public function test_meal_plan_model_updates_meal_slot(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $date = now()->addDays(3)->toDateString();
        $plan = MealPlan::create([
            'user_id' => $user->id,
            'recipe_id' => $recipe->id,
            'planned_date' => $date,
            'meal_slot' => 'breakfast',
        ]);

        $plan->update(['meal_slot' => 'snack']);

        $this->assertSame('snack', $plan->fresh()->meal_slot);
    }

    public function test_meal_plan_model_can_be_deleted(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $date = now()->addDays(4)->toDateString();
        $plan = MealPlan::create([
            'user_id' => $user->id,
            'recipe_id' => $recipe->id,
            'planned_date' => $date,
            'meal_slot' => 'dinner',
        ]);

        $plan->delete();

        $this->assertDatabaseMissing('meal_plans', ['id' => $plan->id]);
    }

    public function test_category_model_persists(): void
    {
        $cat = Category::factory()->create(['name' => 'CatModelA']);

        $this->assertDatabaseHas('categories', ['name' => 'CatModelA']);
    }

    public function test_category_model_has_recipes_relation(): void
    {
        $cat = Category::factory()->create();
        Recipe::factory()->withoutIngredients()->create(['category_id' => $cat->id]);

        $this->assertGreaterThanOrEqual(1, $cat->fresh()->recipes()->count());
    }

    public function test_category_model_updates_description(): void
    {
        $cat = Category::factory()->create(['description' => 'old']);

        $cat->update(['description' => 'new']);

        $this->assertSame('new', $cat->fresh()->description);
    }

    public function test_category_model_can_be_deleted_when_unused(): void
    {
        $cat = Category::factory()->create(['name' => 'CatModelUnused']);

        $cat->delete();

        $this->assertDatabaseMissing('categories', ['id' => $cat->id]);
    }

    public function test_recipe_view_model_persists(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $view = RecipeView::create([
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'view_date' => now()->toDateString(),
        ]);

        $this->assertDatabaseHas('recipe_views', ['id' => $view->id]);
    }

    public function test_recipe_view_model_belongs_to_recipe(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $view = RecipeView::create([
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'view_date' => now()->subDay()->toDateString(),
        ]);

        $this->assertTrue($view->recipe->is($recipe));
    }

    public function test_recipe_view_model_unique_per_day_constraint(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $d = now()->subDays(2)->toDateString();
        RecipeView::create([
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'view_date' => $d,
        ]);

        $this->expectException(\Illuminate\Database\QueryException::class);
        RecipeView::create([
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'view_date' => $d,
        ]);
    }

    public function test_recipe_view_model_can_be_deleted(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        $view = RecipeView::create([
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'view_date' => now()->subDays(5)->toDateString(),
        ]);

        $view->delete();

        $this->assertDatabaseMissing('recipe_views', ['id' => $view->id]);
    }

    public function test_post_model_persists(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'x',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $this->assertDatabaseHas('posts', ['id' => $post->id]);
    }

    public function test_post_model_belongs_to_user(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'x',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $this->assertTrue($post->user->is($user));
    }

    public function test_post_model_updates_content(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'a',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $post->update(['content' => 'b']);

        $this->assertSame('b', $post->fresh()->content);
    }

    public function test_post_model_can_be_deleted(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'x',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $post->delete();

        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
    }

    public function test_message_model_persists(): void
    {
        $u1 = $this->createUser();
        $u2 = $this->createUser();
        $conv = Conversation::create([
            'user1_id' => $u1->id,
            'user2_id' => $u2->id,
            'last_message_at' => now(),
        ]);
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'user_id' => $u1->id,
            'content' => 'hello',
        ]);

        $this->assertDatabaseHas('messages', ['id' => $msg->id]);
    }

    public function test_message_model_belongs_to_conversation(): void
    {
        $u1 = $this->createUser();
        $u2 = $this->createUser();
        $conv = Conversation::create([
            'user1_id' => $u1->id,
            'user2_id' => $u2->id,
            'last_message_at' => now(),
        ]);
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'user_id' => $u1->id,
            'content' => 'c',
        ]);

        $this->assertTrue($msg->conversation->is($conv));
    }

    public function test_message_model_updates_content(): void
    {
        $u1 = $this->createUser();
        $u2 = $this->createUser();
        $conv = Conversation::create([
            'user1_id' => $u1->id,
            'user2_id' => $u2->id,
            'last_message_at' => now(),
        ]);
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'user_id' => $u1->id,
            'content' => 'a',
        ]);

        $msg->update(['content' => 'b']);

        $this->assertSame('b', $msg->fresh()->content);
    }

    public function test_message_model_can_be_deleted(): void
    {
        $u1 = $this->createUser();
        $u2 = $this->createUser();
        $conv = Conversation::create([
            'user1_id' => $u1->id,
            'user2_id' => $u2->id,
            'last_message_at' => now(),
        ]);
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'user_id' => $u1->id,
            'content' => 'c',
        ]);

        $msg->delete();

        $this->assertDatabaseMissing('messages', ['id' => $msg->id]);
    }

    public function test_post_comment_model_persists(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'p',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $c = PostComment::create([
            'user_id' => $user->id,
            'post_id' => $post->id,
            'comment' => 'nice',
        ]);

        $this->assertDatabaseHas('post_comments', ['id' => $c->id]);
    }

    public function test_post_comment_model_belongs_to_post(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'p',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $c = PostComment::create([
            'user_id' => $user->id,
            'post_id' => $post->id,
            'comment' => 'c',
        ]);

        $this->assertTrue($c->post->is($post));
    }

    public function test_post_comment_model_updates_text(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'p',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $c = PostComment::create([
            'user_id' => $user->id,
            'post_id' => $post->id,
            'comment' => 'a',
        ]);

        $c->update(['comment' => 'b']);

        $this->assertSame('b', $c->fresh()->comment);
    }

    public function test_post_comment_model_can_be_deleted(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'p',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $c = PostComment::create([
            'user_id' => $user->id,
            'post_id' => $post->id,
            'comment' => 'c',
        ]);

        $c->delete();

        $this->assertDatabaseMissing('post_comments', ['id' => $c->id]);
    }

    public function test_image_model_persists_on_recipe(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $img = $recipe->images()->create(['path' => 'recipes/img1.jpg', 'sort_order' => 0]);

        $this->assertDatabaseHas('images', ['id' => $img->id]);
    }

    public function test_image_model_morphs_to_recipe(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $img = Image::create([
            'path' => 'recipes/img2.jpg',
            'sort_order' => 0,
            'imageable_id' => $recipe->id,
            'imageable_type' => $recipe->getMorphClass(),
        ]);

        $this->assertInstanceOf(Recipe::class, $img->imageable);
    }

    public function test_image_model_updates_sort_order(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $img = $recipe->images()->create(['path' => 'recipes/img3.jpg', 'sort_order' => 0]);

        $img->update(['sort_order' => 3]);

        $this->assertSame(3, (int) $img->fresh()->sort_order);
    }

    public function test_image_model_can_be_deleted(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $img = $recipe->images()->create(['path' => 'recipes/img4.jpg', 'sort_order' => 0]);

        $img->delete();

        $this->assertDatabaseMissing('images', ['id' => $img->id]);
    }

    public function test_meal_plan_day_skip_model_persists(): void
    {
        $user = $this->createUser();
        $row = MealPlanDaySkip::create([
            'user_id' => $user->id,
            'skipped_date' => now()->addDays(10)->toDateString(),
        ]);

        $this->assertDatabaseHas('meal_plan_day_skips', ['id' => $row->id]);
    }

    public function test_meal_plan_day_skip_model_belongs_to_user(): void
    {
        $user = $this->createUser();
        $row = MealPlanDaySkip::create([
            'user_id' => $user->id,
            'skipped_date' => now()->addDays(11)->toDateString(),
        ]);

        $this->assertTrue($row->user->is($user));
    }

    public function test_meal_plan_day_skip_model_updates_date(): void
    {
        $user = $this->createUser();
        $row = MealPlanDaySkip::create([
            'user_id' => $user->id,
            'skipped_date' => now()->addDays(12)->toDateString(),
        ]);

        $newDate = now()->addDays(13)->toDateString();
        $row->update(['skipped_date' => $newDate]);

        $this->assertSame($newDate, $row->fresh()->skipped_date->toDateString());
    }

    public function test_meal_plan_day_skip_model_can_be_deleted(): void
    {
        $user = $this->createUser();
        $row = MealPlanDaySkip::create([
            'user_id' => $user->id,
            'skipped_date' => now()->addDays(14)->toDateString(),
        ]);

        $row->delete();

        $this->assertDatabaseMissing('meal_plan_day_skips', ['id' => $row->id]);
    }

    public function test_meal_plan_meal_skip_model_persists(): void
    {
        $user = $this->createUser();
        $row = MealPlanMealSkip::create([
            'user_id' => $user->id,
            'skipped_date' => now()->addDays(20)->toDateString(),
            'meal_slot' => 'breakfast',
        ]);

        $this->assertDatabaseHas('meal_plan_meal_skips', ['id' => $row->id]);
    }

    public function test_meal_plan_meal_skip_model_belongs_to_user(): void
    {
        $user = $this->createUser();
        $row = MealPlanMealSkip::create([
            'user_id' => $user->id,
            'skipped_date' => now()->addDays(21)->toDateString(),
            'meal_slot' => 'lunch',
        ]);

        $this->assertTrue($row->user->is($user));
    }

    public function test_meal_plan_meal_skip_model_updates_slot(): void
    {
        $user = $this->createUser();
        $row = MealPlanMealSkip::create([
            'user_id' => $user->id,
            'skipped_date' => now()->addDays(22)->toDateString(),
            'meal_slot' => 'dinner',
        ]);

        $row->update(['meal_slot' => 'snack']);

        $this->assertSame('snack', $row->fresh()->meal_slot);
    }

    public function test_meal_plan_meal_skip_model_can_be_deleted(): void
    {
        $user = $this->createUser();
        $row = MealPlanMealSkip::create([
            'user_id' => $user->id,
            'skipped_date' => now()->addDays(23)->toDateString(),
            'meal_slot' => 'dinner',
        ]);

        $row->delete();

        $this->assertDatabaseMissing('meal_plan_meal_skips', ['id' => $row->id]);
    }

    public function test_ingredient_model_persists(): void
    {
        $ing = Ingredient::create(['name' => 'IngredientModelZ']);

        $this->assertDatabaseHas('ingredients', ['name' => 'IngredientModelZ']);
    }

    public function test_ingredient_model_links_via_recipe_pivot(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $ing = Ingredient::create(['name' => 'IngredientModelY']);
        $recipe->ingredients()->attach($ing->id);

        $this->assertTrue($recipe->fresh()->ingredients()->whereKey($ing->id)->exists());
    }

    public function test_ingredient_model_updates_name_when_unique(): void
    {
        $ing = Ingredient::create(['name' => 'IngredientModelW']);

        $ing->update(['name' => 'IngredientModelW2']);

        $this->assertSame('IngredientModelW2', $ing->fresh()->name);
    }

    public function test_ingredient_model_can_be_deleted_when_detached(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();
        $ing = Ingredient::create(['name' => 'IngredientModelV']);
        $recipe->ingredients()->attach($ing->id);
        $recipe->ingredients()->detach($ing->id);

        $ing->delete();

        $this->assertDatabaseMissing('ingredients', ['id' => $ing->id]);
    }

    public function test_conversation_model_persists(): void
    {
        $a = $this->createUser();
        $b = $this->createUser();
        $c = Conversation::create([
            'user1_id' => $a->id,
            'user2_id' => $b->id,
            'last_message_at' => now(),
        ]);

        $this->assertDatabaseHas('conversations', ['id' => $c->id]);
    }

    public function test_conversation_model_stores_participants(): void
    {
        $a = $this->createUser();
        $b = $this->createUser();
        $c = Conversation::create([
            'user1_id' => $a->id,
            'user2_id' => $b->id,
            'last_message_at' => now(),
        ]);

        $this->assertSame($a->id, (int) $c->user1_id);
        $this->assertSame($b->id, (int) $c->user2_id);
    }

    public function test_conversation_model_updates_last_message_at(): void
    {
        $a = $this->createUser();
        $b = $this->createUser();
        $c = Conversation::create([
            'user1_id' => $a->id,
            'user2_id' => $b->id,
            'last_message_at' => now()->subHour(),
        ]);

        $c->update(['last_message_at' => now()]);

        $this->assertTrue($c->fresh()->last_message_at->greaterThan(now()->subMinute()));
    }

    public function test_conversation_model_can_be_deleted(): void
    {
        $a = $this->createUser();
        $b = $this->createUser();
        $c = Conversation::create([
            'user1_id' => $a->id,
            'user2_id' => $b->id,
            'last_message_at' => now(),
        ]);

        $c->delete();

        $this->assertDatabaseMissing('conversations', ['id' => $c->id]);
    }

    public function test_recipe_model_persists_from_factory(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create(['title' => 'ModelRecipeTitle']);

        $this->assertDatabaseHas('recipes', ['title' => 'ModelRecipeTitle']);
    }

    public function test_recipe_model_belongs_to_category(): void
    {
        $cat = Category::factory()->create();
        $recipe = Recipe::factory()->withoutIngredients()->create(['category_id' => $cat->id]);

        $this->assertTrue($recipe->category->is($cat));
    }

    public function test_recipe_model_updates_title(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create(['title' => 'T1']);

        $recipe->update(['title' => 'T2']);

        $this->assertSame('T2', $recipe->fresh()->title);
    }

    public function test_recipe_model_can_be_deleted(): void
    {
        $recipe = Recipe::factory()->withoutIngredients()->create();

        $id = $recipe->id;
        $recipe->delete();

        $this->assertDatabaseMissing('recipes', ['id' => $id]);
    }
}
