<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_get_notifications_returns_categories_and_counts_for_authenticated_user(): void
    {
        $user = $this->createUser();

        $user->notifications()->create([
            'id' => Str::uuid()->toString(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => ['type' => 'new_message', 'message' => fake()->sentence()],
            'read_at' => null,
        ]);
        $user->notifications()->create([
            'id' => Str::uuid()->toString(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => ['type' => 'recipe_liked', 'message' => fake()->sentence()],
            'read_at' => null,
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('api/notifications');

        $response->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('counts.message_unread', 1)
            ->assertJsonPath('counts.activity_unread', 1);

        $categories = collect($response->json('data'))->pluck('category')->all();
        $this->assertContains('MESSAGE_TYPE', $categories);
        $this->assertContains('ACTIVITY_TYPE', $categories);
    }

    public function test_get_notifications_guest_unauthorized(): void
    {
        $this->getJson('api/notifications')->assertUnauthorized();
    }

    public function test_get_notifications_rejects_invalid_category_filter(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $this->getJson('api/notifications?category=INVALID')
            ->assertStatus(422)
            ->assertJsonFragment(['message' => 'Invalid category']);
    }

    public function test_unread_count_returns_split_counts_for_authenticated_user(): void
    {
        $user = $this->createUser();

        for ($i = 0; $i < 2; $i++) {
            $user->notifications()->create([
                'id' => Str::uuid()->toString(),
                'type' => 'App\Notifications\GenericNotification',
                'data' => ['type' => 'new_message'],
            ]);
        }
        $user->notifications()->create([
            'id' => Str::uuid()->toString(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => ['type' => 'recipe_liked'],
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('api/notifications/unread-count');

        $response->assertOk()
            ->assertJsonPath('counts.message_unread', 2)
            ->assertJsonPath('counts.activity_unread', 1)
            ->assertJsonPath('counts.all_unread', 3);
    }

    public function test_unread_count_guest_unauthorized(): void
    {
        $this->getJson('api/notifications/unread-count')->assertUnauthorized();
    }

    public function test_unread_count_returns_zeros_when_empty(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->getJson('api/notifications/unread-count');

        $response->assertOk()
            ->assertJsonPath('counts.message_unread', 0)
            ->assertJsonPath('counts.activity_unread', 0)
            ->assertJsonPath('counts.all_unread', 0);
    }

    public function test_mark_notification_as_read_succeeds_for_owner(): void
    {
        $user = $this->createUser();
        $notification = $user->notifications()->create([
            'id' => Str::uuid()->toString(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => ['type' => 'new_message'],
        ]);

        Sanctum::actingAs($user);

        $this->patchJson("api/notifications/{$notification->id}/read")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Notification marked as read']);

        $this->assertNotNull($notification->fresh()->read_at);
    }

    public function test_mark_notification_as_read_guest_unauthorized(): void
    {
        $user = $this->createUser();
        $notification = $user->notifications()->create([
            'id' => Str::uuid()->toString(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => ['type' => 'new_message'],
        ]);

        $this->patchJson("api/notifications/{$notification->id}/read")
            ->assertUnauthorized();
    }

    public function test_mark_notification_as_read_returns_404_for_another_users_notification(): void
    {
        $owner = $this->createUser();
        $other = $this->createUser();
        $notification = $owner->notifications()->create([
            'id' => Str::uuid()->toString(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => ['type' => 'new_message'],
        ]);

        Sanctum::actingAs($other);

        $this->patchJson("api/notifications/{$notification->id}/read")
            ->assertNotFound();
    }

    public function test_mark_all_notifications_as_read_succeeds(): void
    {
        $user = $this->createUser();
        $user->notifications()->create([
            'id' => Str::uuid()->toString(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => ['type' => 'new_message'],
        ]);

        Sanctum::actingAs($user);

        $this->postJson('api/notifications/read-all')
            ->assertOk()
            ->assertJsonFragment(['message' => 'All notifications marked as read']);

        $this->assertSame(0, $user->unreadNotifications()->count());
    }

    public function test_mark_all_notifications_as_read_guest_unauthorized(): void
    {
        $this->postJson('api/notifications/read-all')->assertUnauthorized();
    }

    public function test_mark_all_notifications_as_read_is_idempotent(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $this->postJson('api/notifications/read-all')->assertOk();
        $this->postJson('api/notifications/read-all')
            ->assertOk()
            ->assertJsonFragment(['message' => 'All notifications marked as read']);
    }
}
