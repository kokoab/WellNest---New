<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ConversationUnreadCountTest extends TestCase
{
    use RefreshDatabase;

    public function test_unread_count_endpoint_returns_total(): void
    {
        $user = $this->createUser();
        $other = $this->createUser(['email' => 'other-unread@example.com']);
        $conversation = Conversation::create([
            'user1_id' => $user->id,
            'user2_id' => $other->id,
        ]);

        Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $other->id,
            'content' => 'One',
        ]);
        Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $other->id,
            'content' => 'Two',
        ]);

        Sanctum::actingAs($user);

        $this->getJson('api/conversations/unread-count')
            ->assertOk()
            ->assertJsonPath('count', 2);
    }
}
