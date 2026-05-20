<?php

namespace Tests\Feature;

use App\Models\Post;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PostTest extends TestCase
{
    use RefreshDatabase;

    // GET /api/posts

    public function test_get_posts_authenticated_user_can_list_feed(): void
    {
        $viewer = $this->createUser();
        $author = $this->createUser();
        $this->createPost([
            'user_id' => $author->id,
            'content' => 'Hello feed',
            'title' => 'Hi',
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($viewer);

        $response = $this->getJson('api/posts?per_page=5');

        $response->assertOk()
            ->assertJsonStructure(['data', 'meta', 'links']);
        $this->assertGreaterThanOrEqual(1, count($response->json('data')));
    }

    public function test_get_posts_guest_is_unauthorized(): void
    {
        $this->getJson('api/posts')->assertUnauthorized();
    }

    public function test_get_posts_authenticated_user_can_search_feed(): void
    {
        $viewer = $this->createUser();
        $author = $this->createUser();
        $this->createPost([
            'user_id' => $author->id,
            'content' => 'UniqueSearchTermXYZ',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($viewer);

        $response = $this->getJson('api/posts?search=UniqueSearchTermXYZ');

        $response->assertOk();
        $content = collect($response->json('data'))->pluck('content')->all();
        $this->assertTrue(collect($content)->contains(fn ($c) => str_contains((string) $c, 'UniqueSearchTermXYZ')));
    }

    // GET /api/posts/{post}

    public function test_get_post_authenticated_user_can_show_detail(): void
    {
        $viewer = $this->createUser();
        $author = $this->createUser(['email' => 'show-author@example.com']);
        $post = $this->createPost([
            'user_id' => $author->id,
            'content' => 'Body',
            'title' => 'Title',
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($viewer);

        $response = $this->getJson("api/posts/{$post->id}");

        $response->assertOk()
            ->assertJsonFragment(['id' => $post->id, 'content' => 'Body'])
            ->assertJsonPath('user.id', $author->id);
    }

    public function test_get_post_guest_is_unauthorized(): void
    {
        $post = $this->createPost([
            'user_id' => $this->createUser()->id,
            'content' => 'Body',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $this->getJson("api/posts/{$post->id}")->assertUnauthorized();
    }

    public function test_get_post_authenticated_user_gets_404_for_missing(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->getJson('api/posts/999999')->assertNotFound();
    }

    // GET /api/posts/{post}/comments

    public function test_get_post_comments_authenticated_user_can_list(): void
    {
        $viewer = $this->createUser();
        $post = $this->createPost([
            'user_id' => $viewer->id,
            'content' => 'P',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($viewer);

        $response = $this->getJson("api/posts/{$post->id}/comments");

        $response->assertOk();
        $this->assertArrayHasKey('data', $response->json());
    }

    public function test_get_post_comments_guest_is_unauthorized(): void
    {
        $post = $this->createPost([
            'user_id' => $this->createUser()->id,
            'content' => 'P',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $this->getJson("api/posts/{$post->id}/comments")->assertUnauthorized();
    }

    public function test_get_post_comments_authenticated_user_sees_created_comment(): void
    {
        $author = $this->createUser();
        $commenter = $this->createUser(['email' => 'commenter@example.com']);
        $post = $this->createPost([
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

        Sanctum::actingAs($author);
        $response = $this->getJson("api/posts/{$post->id}/comments");

        $response->assertOk();
        $this->assertTrue(collect($response->json('data'))->pluck('comment')->contains('First public comment'));
    }

    // POST /api/posts

    public function test_post_posts_authenticated_user_can_create(): void
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

    public function test_post_posts_authenticated_user_requires_content(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->postJson('api/posts', ['title' => 'Only title'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['content']);
    }

    public function test_post_posts_guest_is_unauthorized(): void
    {
        $this->postJson('api/posts', ['content' => 'Nope'])->assertUnauthorized();
    }

    // PUT /api/posts/{post}

    public function test_put_post_owner_can_update(): void
    {
        $user = $this->createUser();
        $post = $this->createPost([
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

        $response->assertOk()->assertJsonPath('post.content', 'Updated body');
        $this->assertDatabaseHas('posts', ['id' => $post->id, 'content' => 'Updated body']);
    }

    public function test_put_post_non_owner_is_forbidden(): void
    {
        $owner = $this->createUser();
        $other = $this->createUser(['email' => 'other-put@example.com']);
        $post = $this->createPost([
            'user_id' => $owner->id,
            'content' => 'X',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($other);

        $this->putJson("api/posts/{$post->id}", ['content' => 'Hacked'])->assertForbidden();
    }

    public function test_put_post_guest_is_unauthorized(): void
    {
        $post = $this->createPost([
            'user_id' => $this->createUser()->id,
            'content' => 'Old',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $this->putJson("api/posts/{$post->id}", ['content' => 'Hacked'])->assertUnauthorized();
    }

    // DELETE /api/posts/{post}

    public function test_delete_post_owner_can_delete(): void
    {
        $user = $this->createUser();
        $post = $this->createPost([
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

    public function test_delete_post_non_owner_is_forbidden(): void
    {
        $owner = $this->createUser();
        $other = $this->createUser(['email' => 'other-del@example.com']);
        $post = $this->createPost([
            'user_id' => $owner->id,
            'content' => 'X',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($other);

        $this->deleteJson("api/posts/{$post->id}")->assertForbidden();
    }

    public function test_delete_post_guest_is_unauthorized(): void
    {
        $post = $this->createPost([
            'user_id' => $this->createUser()->id,
            'content' => 'Del',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);

        $this->deleteJson("api/posts/{$post->id}")->assertUnauthorized();
    }

    // POST /api/posts/{post}/images

    public function test_post_post_image_owner_can_upload(): void
    {
        Storage::fake('public');
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $response = $this->postJson("api/posts/{$post->id}/images", [
            'image' => UploadedFile::fake()->create('post.jpg', 100, 'image/jpeg'),
        ]);

        $response->assertCreated()
            ->assertJsonFragment(['message' => 'Image uploaded successfully']);
        $this->assertNotEmpty($response->json('image_url'));
    }

    public function test_post_post_image_non_owner_is_forbidden(): void
    {
        Storage::fake('public');
        $owner = $this->createUser();
        $intruder = $this->createUser(['email' => 'intruder-img@example.com']);
        $post = $this->createPost([
            'user_id' => $owner->id,
            'content' => 'Mine',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        Sanctum::actingAs($intruder);

        $this->postJson("api/posts/{$post->id}/images", [
            'image' => UploadedFile::fake()->create('post.jpg', 100, 'image/jpeg'),
        ])->assertForbidden();
    }

    public function test_post_post_image_guest_is_unauthorized(): void
    {
        $post = $this->createPost(['user_id' => $this->createUser()->id]);

        $this->postJson("api/posts/{$post->id}/images", [
            'image' => UploadedFile::fake()->create('post.jpg', 100, 'image/jpeg'),
        ])->assertUnauthorized();
    }

    // DELETE /api/posts/{post}/images/{image}

    public function test_delete_post_image_owner_can_delete(): void
    {
        $user = $this->createUser();
        $post = $this->createPost([
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

    public function test_delete_post_image_owner_gets_404_for_wrong_post(): void
    {
        $user = $this->createUser();
        $postA = $this->createPost([
            'user_id' => $user->id,
            'content' => 'A',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $postB = $this->createPost([
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

    public function test_delete_post_image_guest_is_unauthorized(): void
    {
        $post = $this->createPost([
            'user_id' => $this->createUser()->id,
            'content' => 'Has image',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $img = $post->images()->create(['path' => 'posts/test1.jpg', 'sort_order' => 0]);

        $this->deleteJson("api/posts/{$post->id}/images/{$img->id}")->assertUnauthorized();
    }

    // PUT /api/posts/{post}/images/reorder

    public function test_put_post_images_reorder_owner_can_reorder(): void
    {
        $user = $this->createUser();
        $post = $this->createPost([
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

    public function test_put_post_images_reorder_non_owner_is_forbidden(): void
    {
        $owner = $this->createUser();
        $other = $this->createUser(['email' => 'reorder-other@example.com']);
        $post = $this->createPost([
            'user_id' => $owner->id,
            'content' => 'Gallery',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $i1 = $post->images()->create(['path' => 'posts/o1.jpg', 'sort_order' => 0]);
        $i2 = $post->images()->create(['path' => 'posts/o2.jpg', 'sort_order' => 1]);
        Sanctum::actingAs($other);

        $this->putJson("api/posts/{$post->id}/images/reorder", [
            'image_ids' => [$i2->id, $i1->id],
        ])->assertForbidden();
    }

    public function test_put_post_images_reorder_guest_is_unauthorized(): void
    {
        $post = $this->createPost([
            'user_id' => $this->createUser()->id,
            'content' => 'G',
            'title' => null,
            'recipe_id' => null,
            'image_url' => null,
        ]);
        $post->images()->create(['path' => 'posts/x1.jpg', 'sort_order' => 0]);

        $this->putJson("api/posts/{$post->id}/images/reorder", [
            'image_ids' => [],
        ])->assertUnauthorized();
    }

    // POST /api/posts/{post}/comments

    public function test_post_post_comment_authenticated_user_can_create(): void
    {
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $response = $this->postJson("api/posts/{$post->id}/comments", [
            'comment' => 'Nice post!',
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('post_comments', [
            'post_id' => $post->id,
            'user_id' => $user->id,
            'comment' => 'Nice post!',
        ]);
    }

    public function test_post_post_comment_authenticated_user_requires_text_or_image(): void
    {
        $user = $this->createUser();
        $post = $this->createPost(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->postJson("api/posts/{$post->id}/comments", ['comment' => ''])
            ->assertStatus(422)
            ->assertJsonFragment(['message' => 'Comment or image is required.']);
    }

    public function test_post_post_comment_guest_is_unauthorized(): void
    {
        $post = $this->createPost(['user_id' => $this->createUser()->id]);

        $this->postJson("api/posts/{$post->id}/comments", ['comment' => 'Hi'])
            ->assertUnauthorized();
    }
}
