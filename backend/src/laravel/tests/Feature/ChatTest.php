<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;
use Illuminate\Support\Facades\Hash;

class ChatTest extends TestCase
{
    use RefreshDatabase;

    private function createUser(array $overrides = []): User
    {
        return User::create(array_merge([
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => 'test@example.com',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'account_status' => 'active',
            'is_admin' => false,
        ], $overrides));
    }

    public function test_user_can_create_conversation(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'other@example.com']);

        Sanctum::actingAs($user);

        $response = $this->postJson('api/conversations', [
            'user_id' => $otherUser->id
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('conversations', [
            'user1_id' => $user->id,
            'user2_id' => $otherUser->id
        ]);
    }

    public function test_user_can_send_message(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'other@example.com']);
        $conversation = Conversation::create([
            'user1_id' => $user->id,
            'user2_id' => $otherUser->id
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson("api/conversations/{$conversation->id}/messages", [
            'content' => 'Hello there!'
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('messages', [
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'content' => 'Hello there!'
        ]);
    }

    public function test_user_can_list_messages_in_conversation(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'other@example.com']);
        $conversation = Conversation::create([
            'user1_id' => $user->id,
            'user2_id' => $otherUser->id
        ]);

        Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'content' => 'Message 1'
        ]);

        Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $otherUser->id,
            'content' => 'Message 2'
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson("api/conversations/{$conversation->id}/messages");

        $response->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_user_can_list_conversations(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'other@example.com']);
        Conversation::create([
            'user1_id' => $user->id,
            'user2_id' => $otherUser->id
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('api/conversations');

        $response->assertOk()
            ->assertJsonCount(1);
    }

    public function test_user_can_mark_conversation_as_read(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'other@example.com']);
        $conversation = Conversation::create([
            'user1_id' => $user->id,
            'user2_id' => $otherUser->id
        ]);

        $message = Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $otherUser->id,
            'content' => 'Unread message'
        ]);

        Sanctum::actingAs($user);

        $response = $this->patchJson("api/conversations/{$conversation->id}/messages/read");

        $response->assertOk();
        $this->assertNotNull($message->fresh()->read_at);
    }
}
