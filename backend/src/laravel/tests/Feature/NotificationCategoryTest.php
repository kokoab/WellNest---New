<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationCategoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_notifications_have_correct_categories_and_counts()
    {
        $user = $this->createUser();

        // Create a message notification
        $user->notifications()->create([
            'id' => \Illuminate\Support\Str::uuid(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => [
                'type' => 'new_message',
                'message' => 'Hello',
            ],
            'read_at' => null,
        ]);

        // Create an activity notification
        $user->notifications()->create([
            'id' => \Illuminate\Support\Str::uuid(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => [
                'type' => 'recipe_liked',
                'message' => 'Liked',
            ],
            'read_at' => null,
        ]);

        Sanctum::actingAs($user);
        $response = $this->getJson('api/notifications');

        $response->assertStatus(200)
                 ->assertJsonCount(2, 'data')
                 ->assertJsonPath('counts.message_unread', 1)
                 ->assertJsonPath('counts.activity_unread', 1);

        // Verify categories in individual items
        $data = $response->json('data');
        
        $types = collect($data)->pluck('category')->toArray();
        $this->assertContains('MESSAGE_TYPE', $types);
        $this->assertContains('ACTIVITY_TYPE', $types);
    }

    public function test_unread_count_endpoint_returns_split_counts()
    {
        $user = $this->createUser();

        // 2 messages, 1 activity unread
        for ($i=0; $i<2; $i++) {
            $user->notifications()->create([
                'id' => \Illuminate\Support\Str::uuid(),
                'type' => 'App\Notifications\GenericNotification',
                'data' => ['type' => 'new_message'],
            ]);
        }
        $user->notifications()->create([
            'id' => \Illuminate\Support\Str::uuid(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => ['type' => 'recipe_liked'],
        ]);

        Sanctum::actingAs($user);
        $response = $this->getJson('api/notifications/unread-count');

        $response->assertStatus(200)
                 ->assertJsonPath('counts.message_unread', 2)
                 ->assertJsonPath('counts.activity_unread', 1)
                 ->assertJsonPath('counts.all_unread', 3);
    }

    public function test_filtering_by_category()
    {
        $user = $this->createUser();

        $user->notifications()->create([
            'id' => \Illuminate\Support\Str::uuid(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => ['type' => 'new_message'],
        ]);
        $user->notifications()->create([
            'id' => \Illuminate\Support\Str::uuid(),
            'type' => 'App\Notifications\GenericNotification',
            'data' => ['type' => 'recipe_liked'],
        ]);

        Sanctum::actingAs($user);
        $response = $this->getJson('api/notifications?category=MESSAGE_TYPE');
        $response->assertStatus(200)->assertJsonCount(1, 'data');
        $this->assertEquals('MESSAGE_TYPE', $response->json('data.0.category'));
    }
}
