<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Post;
use App\Models\Recipe;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SocialTest extends TestCase
{
    use RefreshDatabase;


    public function test_user_can_comment_on_post(): void
    {
        $user = $this->createUser();
        $post = $this->createPost([
            'user_id' => $user->id,
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson("api/posts/{$post->id}/comments", [
            'comment' => 'Nice post!'
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('post_comments', [
            'post_id' => $post->id,
            'user_id' => $user->id,
            'comment' => 'Nice post!'
        ]);
    }

    public function test_user_can_like_and_unlike_post(): void
    {
        $user = $this->createUser();
        $post = $this->createPost([
            'user_id' => $user->id,
        ]);
        
        Sanctum::actingAs($user);

        // Like
        $response = $this->postJson("api/posts/{$post->id}/like");
        $response->assertSuccessful();
        $this->assertDatabaseHas('votes', [
            'votable_id' => $post->id,
            'votable_type' => Post::class,
            'user_id' => $user->id
        ]);

        // Unlike
        $response = $this->deleteJson("api/posts/{$post->id}/like");
        $response->assertOk();
        $this->assertDatabaseMissing('votes', [
            'votable_id' => $post->id,
            'votable_type' => Post::class,
            'user_id' => $user->id
        ]);
    }

    public function test_user_can_report_post(): void
    {
        $user = $this->createUser();
        $post = $this->createPost([
            'user_id' => $user->id,
        ]);
        Sanctum::actingAs($user);

        $response = $this->postJson("api/posts/{$post->id}/report", [
            'reason' => 'Spam',
            'description' => 'This is clearly spam.'
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('reports', [
            'reportable_id' => $post->id,
            'reportable_type' => Post::class,
            'user_id' => $user->id,
            'reason' => 'Spam'
        ]);
    }

    public function test_user_can_report_recipe(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory(['name' => 'Test Cat', 'description' => 'Test Desc']);
        $recipe = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Test',
            'instructions' => 'Test',
            'prep_time' => 10
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson("api/recipes/{$recipe->id}/report", [
            'reason' => 'Inappropriate',
            'description' => 'Not a recipe.'
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('reports', [
            'reportable_id' => $recipe->id,
            'reportable_type' => Recipe::class,
            'user_id' => $user->id,
            'reason' => 'Inappropriate'
        ]);
    }

    public function test_categories_listing(): void
    {
        $this->createCategory(['name' => 'Cat 1', 'description' => 'Desc 1']);
        $this->createCategory(['name' => 'Cat 2', 'description' => 'Desc 2']);

        $response = $this->getJson('api/categories');

        $response->assertOk()
            ->assertJsonCount(2);
    }

    public function test_user_can_follow_and_unfollow_user(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'other@example.com']);

        Sanctum::actingAs($user);

        // Follow
        $response = $this->postJson("api/users/{$otherUser->id}/follow");
        $response->assertSuccessful();
        $this->assertTrue($user->following()->where('following_id', $otherUser->id)->exists());

        // Unfollow
        $response = $this->deleteJson("api/users/{$otherUser->id}/follow");
        $response->assertOk();
        $this->assertFalse($user->following()->where('following_id', $otherUser->id)->exists());
    }

    public function test_user_can_view_post_likes(): void
    {
        $user = $this->createUser();
        $post = $this->createPost([
            'user_id' => $user->id,
        ]);  
        Sanctum::actingAs($user);
        $this->postJson("api/posts/{$post->id}/like");

        $response = $this->getJson("api/posts/{$post->id}/likes");

        $response->assertOk()
            ->assertJson([
                'is_liked' => true,
                'likes_count' => 1
            ]);
    }
}
