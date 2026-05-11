<?php

namespace Tests\Feature;

use App\Models\Post;
use App\Models\Recipe;
use App\Models\RecipeStep;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SupplementalApiCoverageTest extends TestCase
{
    use RefreshDatabase;

    public function test_guest_can_list_posts_feed(): void
    {
        $author = $this->createUser();
        Post::create([
            'user_id' => $author->id,
            'content' => 'Hello feed',
            'title' => 'Hi',
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $response = $this->getJson('api/posts?per_page=5');

        $response->assertOk()
            ->assertJsonStructure(['data', 'meta', 'links']);

        $this->assertGreaterThanOrEqual(1, count($response->json('data')));
    }

    public function test_posts_feed_supports_search_query(): void
    {
        $author = $this->createUser();
        Post::create([
            'user_id' => $author->id,
            'content' => 'UniqueSearchTermXYZ',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $response = $this->getJson('api/posts?search=UniqueSearchTermXYZ');

        $response->assertOk();
        $titlesOrContent = collect($response->json('data'))->pluck('content')->all();
        $this->assertTrue(collect($titlesOrContent)->contains(fn ($c) => str_contains((string) $c, 'UniqueSearchTermXYZ')));
    }

    public function test_guest_can_show_post_detail(): void
    {
        $author = $this->createUser();
        $post = Post::create([
            'user_id' => $author->id,
            'content' => 'Body',
            'title' => 'Title',
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $response = $this->getJson("api/posts/{$post->id}");

        $response->assertOk()
            ->assertJsonFragment(['id' => $post->id, 'content' => 'Body']);
    }

    public function test_show_post_returns_404_for_missing_post(): void
    {
        $this->getJson('api/posts/999999')->assertNotFound();
    }

    public function test_guest_can_list_post_comments(): void
    {
        $author = $this->createUser();
        $post = Post::create([
            'user_id' => $author->id,
            'content' => 'P',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $response = $this->getJson("api/posts/{$post->id}/comments");

        $response->assertOk();
        $this->assertArrayHasKey('data', $response->json());
    }

    public function test_guest_sees_post_comments_after_creation(): void
    {
        $author = $this->createUser();
        $commenter = $this->createUser();
        $post = Post::create([
            'user_id' => $author->id,
            'content' => 'P',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        Sanctum::actingAs($commenter);
        $this->postJson("api/posts/{$post->id}/comments", [
            'comment' => 'First public comment',
        ])->assertCreated();

        $response = $this->getJson("api/posts/{$post->id}/comments");

        $response->assertOk();
        $this->assertTrue(collect($response->json('data'))->pluck('comment')->contains('First public comment'));
    }

    public function test_guest_can_view_public_user_profile(): void
    {
        $subject = $this->createUser(['first_name' => 'Public', 'last_name' => 'Profile']);

        $response = $this->getJson("api/users/{$subject->id}");

        $response->assertOk()
            ->assertJsonFragment([
                'id' => $subject->id,
                'first_name' => 'Public',
                'last_name' => 'Profile',
            ]);
    }

    public function test_authenticated_viewer_sees_is_following_on_user_profile(): void
    {
        $viewer = $this->createUser();
        $subject = $this->createUser();
        Sanctum::actingAs($viewer);

        $response = $this->getJson("api/users/{$subject->id}");

        $response->assertOk()
            ->assertJsonPath('is_following', false);
    }

    public function test_user_can_create_text_post(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('api/posts', [
            'content' => 'My new post content',
            'title' => 'Optional title',
        ]);

        $response->assertCreated()
            ->assertJsonPath('post.content', 'My new post content');

        $this->assertDatabaseHas('posts', [
            'user_id' => $user->id,
            'content' => 'My new post content',
        ]);
    }

    public function test_create_post_requires_content(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $this->postJson('api/posts', [
            'title' => 'Only title',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['content']);
    }

    public function test_owner_can_update_post(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'Old',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($user);

        $response = $this->putJson("api/posts/{$post->id}", [
            'content' => 'Updated body',
            'title' => 'New title',
        ]);

        $response->assertOk()
            ->assertJsonPath('post.content', 'Updated body');

        $this->assertDatabaseHas('posts', ['id' => $post->id, 'content' => 'Updated body']);
    }

    public function test_non_owner_cannot_update_post(): void
    {
        $owner = $this->createUser();
        $other = $this->createUser();
        $post = Post::create([
            'user_id' => $owner->id,
            'content' => 'X',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($other);

        $this->putJson("api/posts/{$post->id}", [
            'content' => 'Hacked',
        ])->assertForbidden();
    }

    public function test_owner_can_delete_post(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'Del',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($user);

        $this->deleteJson("api/posts/{$post->id}")->assertOk();

        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
    }

    public function test_non_owner_cannot_delete_post(): void
    {
        $owner = $this->createUser();
        $other = $this->createUser();
        $post = Post::create([
            'user_id' => $owner->id,
            'content' => 'X',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($other);

        $this->deleteJson("api/posts/{$post->id}")->assertForbidden();
    }

    public function test_owner_can_delete_post_image(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'Has image',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $img = $post->images()->create(['path' => 'posts/test1.jpg', 'sort_order' => 0]);
        Sanctum::actingAs($user);

        $this->deleteJson("api/posts/{$post->id}/images/{$img->id}")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Image deleted']);

        $this->assertDatabaseMissing('images', ['id' => $img->id]);
    }

    public function test_owner_cannot_delete_image_from_another_post(): void
    {
        $user = $this->createUser();
        $postA = Post::create([
            'user_id' => $user->id,
            'content' => 'A',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $postB = Post::create([
            'user_id' => $user->id,
            'content' => 'B',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $imgB = $postB->images()->create(['path' => 'posts/b.jpg', 'sort_order' => 0]);
        Sanctum::actingAs($user);

        $this->deleteJson("api/posts/{$postA->id}/images/{$imgB->id}")->assertNotFound();
    }

    public function test_owner_can_reorder_post_images(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'Gallery',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $i1 = $post->images()->create(['path' => 'posts/o1.jpg', 'sort_order' => 0]);
        $i2 = $post->images()->create(['path' => 'posts/o2.jpg', 'sort_order' => 1]);
        Sanctum::actingAs($user);

        $this->putJson("api/posts/{$post->id}/images/reorder", [
            'image_ids' => [$i2->id, $i1->id],
        ])->assertOk()->assertJsonFragment(['message' => 'Order updated']);

        $this->assertSame(0, (int) $i2->fresh()->sort_order);
        $this->assertSame(1, (int) $i1->fresh()->sort_order);
    }

    public function test_reorder_post_images_rejects_incomplete_id_list(): void
    {
        $user = $this->createUser();
        $post = Post::create([
            'user_id' => $user->id,
            'content' => 'G',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $post->images()->create(['path' => 'posts/x1.jpg', 'sort_order' => 0]);
        $post->images()->create(['path' => 'posts/x2.jpg', 'sort_order' => 1]);
        Sanctum::actingAs($user);

        $this->putJson("api/posts/{$post->id}/images/reorder", [
            'image_ids' => [],
        ])->assertStatus(422);
    }

    public function test_user_can_like_and_unlike_recipe(): void
    {
        $owner = $this->createUser();
        $fan = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $owner->id]);
        Sanctum::actingAs($fan);

        $this->postJson("api/recipes/{$recipe->id}/like")
            ->assertCreated()
            ->assertJsonFragment(['liked' => true]);

        $this->deleteJson("api/recipes/{$recipe->id}/like")
            ->assertOk()
            ->assertJsonFragment(['liked' => false]);
    }

    public function test_like_recipe_twice_returns_already_liked(): void
    {
        $owner = $this->createUser();
        $fan = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $owner->id]);
        Sanctum::actingAs($fan);

        $this->postJson("api/recipes/{$recipe->id}/like")->assertCreated();
        $this->postJson("api/recipes/{$recipe->id}/like")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Already liked']);
    }

    public function test_guest_can_list_recipe_ratings(): void
    {
        $recipe = $this->createRecipe();
        $rater = $this->createUser();
        $recipe->ratings()->create([
            'user_id' => $rater->id,
            'rating' => 5,
            'comment' => 'Great',
        ]);

        $response = $this->getJson("api/recipes/{$recipe->id}/ratings");

        $response->assertOk()
            ->assertJsonStructure(['data', 'average_rating', 'ratings_count']);

        $this->assertCount(1, $response->json('data'));
    }

    public function test_recipe_ratings_endpoint_returns_empty_data_when_none(): void
    {
        $recipe = $this->createRecipe();

        $response = $this->getJson("api/recipes/{$recipe->id}/ratings");

        $response->assertOk();
        $this->assertSame([], $response->json('data'));
    }

    public function test_user_can_mark_single_notification_read(): void
    {
        $user = $this->createUser();
        $id = (string) Str::uuid();
        DB::table('notifications')->insert([
            'id' => $id,
            'type' => 'App\\Notifications\\NewMessageNotification',
            'notifiable_type' => User::class,
            'notifiable_id' => $user->id,
            'data' => json_encode(['type' => 'new_message', 'message' => 'Hi']),
            'read_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        Sanctum::actingAs($user);

        $this->patchJson("api/notifications/{$id}/read")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Notification marked as read']);

        $this->assertNotNull(DB::table('notifications')->where('id', $id)->value('read_at'));
    }

    public function test_mark_notification_read_returns_404_for_other_users_row(): void
    {
        $alice = $this->createUser();
        $bob = $this->createUser();
        $id = (string) Str::uuid();
        DB::table('notifications')->insert([
            'id' => $id,
            'type' => 'App\\Notifications\\NewMessageNotification',
            'notifiable_type' => User::class,
            'notifiable_id' => $alice->id,
            'data' => json_encode(['type' => 'new_message', 'message' => 'Hi']),
            'read_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        Sanctum::actingAs($bob);

        $this->patchJson("api/notifications/{$id}/read")->assertNotFound();
    }

    public function test_user_can_mark_all_notifications_read(): void
    {
        $user = $this->createUser();
        foreach ([1, 2] as $i) {
            DB::table('notifications')->insert([
                'id' => (string) Str::uuid(),
                'type' => 'App\\Notifications\\NewMessageNotification',
                'notifiable_type' => User::class,
                'notifiable_id' => $user->id,
                'data' => json_encode(['type' => 'new_message', 'message' => "m{$i}"]),
                'read_at' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
        Sanctum::actingAs($user);

        $this->postJson('api/notifications/read-all')
            ->assertOk()
            ->assertJsonFragment(['message' => 'All notifications marked as read']);

        $this->assertSame(0, $user->unreadNotifications()->count());
    }

    public function test_mark_all_notifications_read_is_idempotent(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $this->postJson('api/notifications/read-all')->assertOk();
        $this->postJson('api/notifications/read-all')->assertOk();
    }

    public function test_user_can_report_another_user(): void
    {
        $this->createAdmin();
        $reporter = $this->createUser();
        $target = $this->createUser();
        Sanctum::actingAs($reporter);

        $response = $this->postJson("api/users/{$target->id}/report", [
            'reason' => 'Spam behaviour',
            'details' => 'Details here',
        ]);

        $response->assertCreated()
            ->assertJsonFragment(['message' => 'User reported. Admins will review']);

        $this->assertDatabaseHas('reports', [
            'user_id' => $reporter->id,
            'reportable_type' => User::class,
            'reportable_id' => $target->id,
        ]);
    }

    public function test_user_cannot_report_themselves(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $this->postJson("api/users/{$user->id}/report", [
            'reason' => 'Self',
        ])->assertStatus(400);
    }

    public function test_saved_recipes_list_is_empty_initially(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->getJson('api/saved-recipes');

        $response->assertOk();
        $this->assertSame([], $response->json('data'));
    }

    public function test_saved_recipes_lists_saved_recipe_after_save(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/save")->assertCreated();

        $response = $this->getJson('api/saved-recipes');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertContains($recipe->id, $ids);
    }

    public function test_saved_check_returns_false_when_not_saved(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        Sanctum::actingAs($user);

        $this->getJson("api/recipes/{$recipe->id}/saved")
            ->assertOk()
            ->assertJson(['saved' => false]);
    }

    public function test_saved_check_returns_true_when_saved(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/save")->assertCreated();

        $this->getJson("api/recipes/{$recipe->id}/saved")
            ->assertOk()
            ->assertJson(['saved' => true]);
    }

    public function test_admin_can_list_audit_logs_alias(): void
    {
        $admin = $this->createAdmin();
        Sanctum::actingAs($admin);

        $response = $this->getJson('api/admin/audit-logs');

        $response->assertOk();
        $this->assertArrayHasKey('data', $response->json());
    }

    public function test_admin_can_filter_audit_logs_by_category(): void
    {
        $admin = $this->createAdmin();
        Sanctum::actingAs($admin);

        $this->getJson('api/admin/audit-logs?category=auth')->assertOk();
    }

    public function test_admin_audit_logs_export_returns_csv_attachment(): void
    {
        $admin = $this->createAdmin();
        Sanctum::actingAs($admin);

        $response = $this->get('api/admin/audit-logs/export');

        $response->assertOk();
        $this->assertStringContainsString('attachment', strtolower($response->headers->get('content-disposition') ?? ''));
    }

    public function test_admin_audit_logs_export_supports_category_query(): void
    {
        $admin = $this->createAdmin();
        Sanctum::actingAs($admin);

        $response = $this->get('api/admin/audit-logs/export?category=auth');

        $response->assertOk();
    }

    public function test_admin_recipe_rankings_returns_payload(): void
    {
        $admin = $this->createAdmin();
        Sanctum::actingAs($admin);

        $response = $this->getJson('api/admin/recipes/rankings?window=all&mode=combined');

        $response->assertOk();
        $this->assertIsArray($response->json('data'));
    }

    public function test_admin_recipe_rankings_accepts_window_parameter(): void
    {
        $admin = $this->createAdmin();
        Sanctum::actingAs($admin);

        $this->getJson('api/admin/recipes/rankings?window=30d&mode=ratings')->assertOk();
    }

    public function test_owner_can_delete_recipe_cover_image(): void
    {
        $user = $this->createUser();
        $recipe = Recipe::factory()->withoutIngredients()->create(['user_id' => $user->id]);
        $img = $recipe->images()->create(['path' => 'recipes/c1.jpg', 'sort_order' => 0]);
        Sanctum::actingAs($user);

        $this->deleteJson("api/recipes/{$recipe->id}/images/{$img->id}")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Image deleted']);
    }

    public function test_delete_recipe_image_returns_404_for_wrong_owner(): void
    {
        $owner = $this->createUser();
        $intruder = $this->createUser();
        $recipe = Recipe::factory()->withoutIngredients()->create(['user_id' => $owner->id]);
        $img = $recipe->images()->create(['path' => 'recipes/c2.jpg', 'sort_order' => 0]);
        Sanctum::actingAs($intruder);

        $this->deleteJson("api/recipes/{$recipe->id}/images/{$img->id}")->assertForbidden();
    }

    public function test_owner_can_reorder_recipe_images(): void
    {
        $user = $this->createUser();
        $recipe = Recipe::factory()->withoutIngredients()->create(['user_id' => $user->id]);
        $a = $recipe->images()->create(['path' => 'recipes/r1.jpg', 'sort_order' => 0]);
        $b = $recipe->images()->create(['path' => 'recipes/r2.jpg', 'sort_order' => 1]);
        Sanctum::actingAs($user);

        $this->putJson("api/recipes/{$recipe->id}/images/reorder", [
            'image_ids' => [$b->id, $a->id],
        ])->assertOk()->assertJsonFragment(['message' => 'Order updated']);
    }

    public function test_reorder_recipe_images_validates_payload(): void
    {
        $user = $this->createUser();
        $recipe = Recipe::factory()->withoutIngredients()->create(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->putJson("api/recipes/{$recipe->id}/images/reorder", [
            'image_ids' => [999999],
        ])->assertStatus(422);
    }

    public function test_owner_can_upload_and_delete_step_image(): void
    {
        $user = $this->createUser();
        $recipe = Recipe::factory()->withoutIngredients()->create(['user_id' => $user->id]);
        $step = RecipeStep::create([
            'recipe_id' => $recipe->id,
            'sort_order' => 0,
            'title' => 'Mix',
            'instructions' => 'Stir',
            'prep_time_minutes' => 5,
        ]);
        Sanctum::actingAs($user);

        $upload = $this->post("api/recipes/{$recipe->id}/steps/{$step->id}/images", [
            'image' => UploadedFile::fake()->create('step.jpg', 100, 'image/jpeg'),
        ]);

        $upload->assertCreated();
        $imageId = $upload->json('image.id');
        $this->assertNotNull($imageId);

        $this->deleteJson("api/recipes/{$recipe->id}/steps/{$step->id}/images/{$imageId}")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Step image deleted']);
    }

    public function test_step_image_upload_rejects_non_owner(): void
    {
        $owner = $this->createUser();
        $other = $this->createUser();
        $recipe = Recipe::factory()->withoutIngredients()->create(['user_id' => $owner->id]);
        $step = RecipeStep::create([
            'recipe_id' => $recipe->id,
            'sort_order' => 0,
            'title' => 'S',
            'instructions' => 'X',
            'prep_time_minutes' => 1,
        ]);
        Sanctum::actingAs($other);

        $this->post("api/recipes/{$recipe->id}/steps/{$step->id}/images", [
            'image' => UploadedFile::fake()->create('nope.jpg', 100, 'image/jpeg'),
        ])->assertForbidden();
    }

    public function test_user_can_authorize_private_notifications_channel(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/broadcasting/auth', [
            'socket_id' => '1234.5678',
            'channel_name' => 'private-notifications.'.$user->id,
        ]);

        $response->assertOk();
        $this->assertNotEmpty($response->getContent());
    }

    public function test_broadcasting_auth_denies_foreign_notifications_channel(): void
    {
        $user = $this->createUser();
        $other = $this->createUser();
        Sanctum::actingAs($user);

        $this->postJson('/api/broadcasting/auth', [
            'socket_id' => '1234.5678',
            'channel_name' => 'private-notifications.'.$other->id,
        ])->assertForbidden();
    }
}
