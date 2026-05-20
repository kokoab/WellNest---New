<?php

namespace Tests\Feature;

use App\Models\Post;
use App\Models\Recipe;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SocialTest extends TestCase
{
    use RefreshDatabase;

    // POST /api/posts/{post}/like

    public function test_post_post_like_authenticated_user_can_like(): void
    {
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->postJson("api/posts/{$post->id}/like")
            ->assertSuccessful();

        $this->assertDatabaseHas('votes', [
            'votable_id' => $post->id,
            'votable_type' => Post::class,
            'user_id' => $user->id,
        ]);
    }

    public function test_post_post_like_duplicate_returns_already_liked(): void
    {
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->postJson("api/posts/{$post->id}/like")->assertCreated();
        $this->postJson("api/posts/{$post->id}/like")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Already liked']);
    }

    public function test_post_post_like_guest_is_unauthorized(): void
    {
        $post = $this->createPost(['user_id' => $this->createUser()->id]);

        $this->postJson("api/posts/{$post->id}/like")->assertUnauthorized();
    }

    // DELETE /api/posts/{post}/like

    public function test_delete_post_like_authenticated_user_can_unlike(): void
    {
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->postJson("api/posts/{$post->id}/like")->assertSuccessful();
        $this->deleteJson("api/posts/{$post->id}/like")->assertOk();

        $this->assertDatabaseMissing('votes', [
            'votable_id' => $post->id,
            'votable_type' => Post::class,
            'user_id' => $user->id,
        ]);
    }

    public function test_delete_post_like_when_not_liked_is_safe(): void
    {
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->deleteJson("api/posts/{$post->id}/like")
            ->assertOk()
            ->assertJsonFragment(['liked' => false]);
    }

    public function test_delete_post_like_guest_is_unauthorized(): void
    {
        $post = $this->createPost(['user_id' => $this->createUser()->id]);

        $this->deleteJson("api/posts/{$post->id}/like")->assertUnauthorized();
    }

    // GET /api/posts/{post}/likes

    public function test_get_post_likes_authenticated_user_sees_count(): void
    {
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);
        $this->postJson("api/posts/{$post->id}/like");

        $this->getJson("api/posts/{$post->id}/likes")
            ->assertOk()
            ->assertJson(['is_liked' => true, 'likes_count' => 1]);
    }

    public function test_get_post_likes_authenticated_user_sees_zero_when_none(): void
    {
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->getJson("api/posts/{$post->id}/likes")
            ->assertOk()
            ->assertJson(['likes_count' => 0, 'is_liked' => false]);
    }

    public function test_get_post_likes_guest_is_unauthorized(): void
    {
        $post = $this->createPost(['user_id' => $this->createUser()->id]);

        $this->getJson("api/posts/{$post->id}/likes")->assertUnauthorized();
    }

    // POST /api/posts/{post}/report

    public function test_post_post_report_authenticated_user_can_report(): void
    {
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->postJson("api/posts/{$post->id}/report", [
            'reason' => 'Spam',
            'details' => 'This is clearly spam.',
        ])->assertCreated();

        $this->assertDatabaseHas('reports', [
            'reportable_id' => $post->id,
            'reportable_type' => Post::class,
            'user_id' => $user->id,
            'reason' => 'Spam',
        ]);
    }

    public function test_post_post_report_rejects_reason_over_255_chars(): void
    {
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->postJson("api/posts/{$post->id}/report", [
            'reason' => str_repeat('x', 300),
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['reason']);
    }

    public function test_post_post_report_guest_is_unauthorized(): void
    {
        $post = $this->createPost(['user_id' => $this->createUser()->id]);

        $this->postJson("api/posts/{$post->id}/report", ['reason' => 'Spam'])
            ->assertUnauthorized();
    }

    // POST /api/recipes/{recipe}/report

    public function test_post_recipe_report_authenticated_user_can_report(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/report", [
            'reason' => 'Inappropriate',
            'details' => 'Not a recipe.',
        ])->assertCreated();

        $this->assertDatabaseHas('reports', [
            'reportable_id' => $recipe->id,
            'reportable_type' => Recipe::class,
            'user_id' => $user->id,
        ]);
    }

    public function test_post_recipe_report_returns_404_for_missing_recipe(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->postJson('api/recipes/999999/report', ['reason' => 'X'])->assertNotFound();
    }

    public function test_post_recipe_report_guest_is_unauthorized(): void
    {
        $recipe = $this->createRecipe();

        $this->postJson("api/recipes/{$recipe->id}/report", ['reason' => 'X'])
            ->assertUnauthorized();
    }

    // POST /api/users/{user}/follow

    public function test_post_user_follow_authenticated_user_can_follow(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'other@example.com']);
        Sanctum::actingAs($user);

        $this->postJson("api/users/{$otherUser->id}/follow")->assertSuccessful();
        $this->assertTrue($user->following()->where('following_id', $otherUser->id)->exists());
    }

    public function test_post_user_follow_cannot_follow_self(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $this->postJson("api/users/{$user->id}/follow")
            ->assertStatus(422)
            ->assertJsonFragment(['message' => 'You cannot follow yourself.']);
    }

    public function test_post_user_follow_cannot_follow_same_user_twice(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'dup-follow@example.com']);
        Sanctum::actingAs($user);

        $this->postJson("api/users/{$otherUser->id}/follow")->assertCreated();
        $this->postJson("api/users/{$otherUser->id}/follow")
            ->assertStatus(409)
            ->assertJsonFragment(['message' => 'You are already following this user.']);
    }

    public function test_post_user_follow_guest_is_unauthorized(): void
    {
        $other = $this->createUser();

        $this->postJson("api/users/{$other->id}/follow")->assertUnauthorized();
    }

    // DELETE /api/users/{user}/follow

    public function test_delete_user_follow_authenticated_user_can_unfollow(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'unfollow@example.com']);
        Sanctum::actingAs($user);
        $this->postJson("api/users/{$otherUser->id}/follow")->assertCreated();

        $this->deleteJson("api/users/{$otherUser->id}/follow")->assertOk();
        $this->assertFalse($user->following()->where('following_id', $otherUser->id)->exists());
    }

    public function test_delete_user_follow_when_not_following_is_safe(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'never-followed@example.com']);
        Sanctum::actingAs($user);

        $this->deleteJson("api/users/{$otherUser->id}/follow")->assertOk();
    }

    public function test_delete_user_follow_guest_is_unauthorized(): void
    {
        $other = $this->createUser();

        $this->deleteJson("api/users/{$other->id}/follow")->assertUnauthorized();
    }
}
