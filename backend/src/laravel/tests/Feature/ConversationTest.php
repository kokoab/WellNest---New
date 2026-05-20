<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\MessageAttachment;
use App\Models\User;
use App\Notifications\NewMessageNotification;
use App\Support\Assistant;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use ReflectionClass;
use Tests\TestCase;

class ConversationTest extends TestCase
{
    use RefreshDatabase;

    // GET /api/conversations/assistant

    public function test_assistant_endpoint_returns_conversation_when_bot_configured(): void
    {
        $user = $this->createUser();
        $bot = $this->createUser([
            'email' => config('assistant.bot_email'),
            'first_name' => 'WellNest',
            'last_name' => 'Assistant',
        ]);
        config(['assistant.bot_user_id' => $bot->id]);
        $this->resetAssistantCache();

        Sanctum::actingAs($user);

        $response = $this->getJson('api/conversations/assistant');

        $response->assertOk()
            ->assertJsonFragment(['is_assistant' => true]);
    }

    public function test_assistant_endpoint_returns_503_when_bot_not_configured(): void
    {
        $user = $this->createUser();
        config([
            'assistant.bot_user_id' => null,
            'assistant.bot_email' => fake()->uuid().'@assistant-unconfigured.test',
        ]);
        $this->resetAssistantCache();

        Sanctum::actingAs($user);

        $this->getJson('api/conversations/assistant')
            ->assertStatus(503)
            ->assertJsonFragment(['message' => 'Assistant is not configured. Run migrations and AssistantBotSeeder.']);
    }

    public function test_get_conversations_assistant_guest_is_unauthorized(): void
    {
        $this->getJson('api/conversations/assistant')->assertUnauthorized();
    }

    // GET /api/conversations/unread-count

    public function test_unread_count_endpoint_returns_total(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $this->makeMessage($conversation, $other);
        $this->makeMessage($conversation, $other);

        Sanctum::actingAs($user);

        $this->getJson('api/conversations/unread-count')
            ->assertOk()
            ->assertJsonPath('count', 2);
    }

    public function test_unread_count_returns_zero_when_no_unread_messages(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->getJson('api/conversations/unread-count')
            ->assertOk()
            ->assertJsonPath('count', 0);
    }

    public function test_get_conversations_unread_count_guest_is_unauthorized(): void
    {
        $this->getJson('api/conversations/unread-count')->assertUnauthorized();
    }

    // GET /api/conversations

    public function test_user_can_list_conversations(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();

        Sanctum::actingAs($user);

        $response = $this->getJson('api/conversations');

        $response->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_list_conversations_only_returns_own_conversations(): void
    {
        $user = $this->createUser();
        $otherOne = $this->createUser();
        $otherTwo = $this->createUser();

        $this->createConversation([
            'user1_id' => min($user->id, $otherOne->id),
            'user2_id' => max($user->id, $otherOne->id),
        ]);
        $this->createConversation([
            'user1_id' => min($otherOne->id, $otherTwo->id),
            'user2_id' => max($otherOne->id, $otherTwo->id),
        ]);

        Sanctum::actingAs($user);

        $this->getJson('api/conversations')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_get_conversations_guest_is_unauthorized(): void
    {
        $this->getJson('api/conversations')->assertUnauthorized();
    }

    // GET /api/conversations/{conversation}

    public function test_user_can_show_their_conversation(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();

        Sanctum::actingAs($user);

        $response = $this->getJson("api/conversations/{$conversation->id}");

        $response->assertOk()
            ->assertJsonPath('conversation.id', $conversation->id);
    }

    public function test_show_conversation_forbidden_for_non_participant(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $outsider = $this->createUser();

        Sanctum::actingAs($outsider);

        $this->getJson("api/conversations/{$conversation->id}")
            ->assertForbidden();
    }

    public function test_get_conversation_guest_is_unauthorized(): void
    {
        [, , $conversation] = $this->conversationPair();

        $this->getJson("api/conversations/{$conversation->id}")->assertUnauthorized();
    }

    // POST /api/conversations

    public function test_user_can_create_conversation(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser();

        Sanctum::actingAs($user);

        $response = $this->postJson('api/conversations', [
            'user_id' => $otherUser->id,
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('conversations', [
            'user1_id' => min($user->id, $otherUser->id),
            'user2_id' => max($user->id, $otherUser->id),
        ]);
    }

    public function test_duplicate_create_conversation_returns_same_id(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser();

        Sanctum::actingAs($user);

        $first = $this->postJson('api/conversations', ['user_id' => $otherUser->id]);
        $second = $this->postJson('api/conversations', ['user_id' => $otherUser->id]);

        $first->assertCreated();
        $second->assertCreated();
        $this->assertSame($first->json('id'), $second->json('id'));
    }

    public function test_post_conversations_guest_is_unauthorized(): void
    {
        $this->postJson('api/conversations', [
            'user_id' => $this->createUser()->id,
        ])->assertUnauthorized();
    }

    // PUT /api/conversations/{conversation}

    public function test_user_can_update_their_conversation(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();

        Sanctum::actingAs($user);

        $response = $this->putJson("api/conversations/{$conversation->id}", []);

        $response->assertOk()
            ->assertJsonPath('id', $conversation->id);
    }

    public function test_update_conversation_forbidden_for_non_participant(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $outsider = $this->createUser();

        Sanctum::actingAs($outsider);

        $this->putJson("api/conversations/{$conversation->id}", [])
            ->assertForbidden();
    }

    public function test_put_conversation_guest_is_unauthorized(): void
    {
        [, , $conversation] = $this->conversationPair();

        $this->putJson("api/conversations/{$conversation->id}", [])
            ->assertUnauthorized();
    }

    // DELETE /api/conversations/{conversation}

    public function test_user_can_delete_their_conversation(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();

        Sanctum::actingAs($user);

        $response = $this->deleteJson("api/conversations/{$conversation->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('conversations', ['id' => $conversation->id]);
    }

    public function test_delete_conversation_forbidden_for_non_participant(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $outsider = $this->createUser();

        Sanctum::actingAs($outsider);

        $this->deleteJson("api/conversations/{$conversation->id}")
            ->assertForbidden();
    }

    public function test_delete_conversation_guest_is_unauthorized(): void
    {
        [, , $conversation] = $this->conversationPair();

        $this->deleteJson("api/conversations/{$conversation->id}")->assertUnauthorized();
    }

    // GET /api/conversations/{conversation}/messages

    public function test_user_can_list_messages_in_conversation(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $this->makeMessage($conversation, $user);
        $this->makeMessage($conversation, $other);

        Sanctum::actingAs($user);

        $response = $this->getJson("api/conversations/{$conversation->id}/messages");

        $response->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_conversation_messages_routes_forbidden_for_non_participant(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $outsider = $this->createUser();
        $content = fake()->sentence();

        Sanctum::actingAs($outsider);

        $this->getJson("api/conversations/{$conversation->id}/messages")
            ->assertForbidden();

        $this->postJson("api/conversations/{$conversation->id}/messages", [
            'content' => $content,
        ])->assertForbidden();

        $this->patchJson("api/conversations/{$conversation->id}/messages/read")
            ->assertForbidden();
    }

    public function test_get_conversation_messages_guest_is_unauthorized(): void
    {
        [, , $conversation] = $this->conversationPair();

        $this->getJson("api/conversations/{$conversation->id}/messages")->assertUnauthorized();
    }

    // POST /api/conversations/{conversation}/messages

    public function test_user_can_send_message_via_conversation_route(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $content = fake()->sentence();

        Sanctum::actingAs($user);

        $response = $this->postJson("api/conversations/{$conversation->id}/messages", [
            'content' => $content,
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('messages', [
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'content' => $content,
        ]);
    }

    public function test_post_conversation_messages_guest_is_unauthorized(): void
    {
        [, , $conversation] = $this->conversationPair();

        $this->postJson("api/conversations/{$conversation->id}/messages", [
            'content' => fake()->sentence(),
        ])->assertUnauthorized();
    }

    // PATCH /api/conversations/{conversation}/messages/read

    public function test_user_can_mark_conversation_as_read(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $other);

        Sanctum::actingAs($user);

        $response = $this->patchJson("api/conversations/{$conversation->id}/messages/read");

        $response->assertOk();
        $this->assertNotNull($message->fresh()->read_at);
    }

    public function test_user_can_mark_entire_conversation_as_read(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $this->makeMessage($conversation, $other);
        $this->makeMessage($conversation, $other);

        Sanctum::actingAs($user);

        $response = $this->patchJson("api/conversations/{$conversation->id}/messages/read");

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Marked as read']);
    }

    public function test_mark_conversation_as_read_clears_new_message_notifications(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $content = fake()->sentence();
        $this->makeMessage($conversation, $other, $content);

        $user->notify(new NewMessageNotification(
            $conversation->id,
            1,
            $other->name,
            $content,
            $other->id,
            null,
            false,
        ));

        $this->assertSame(
            1,
            $user->unreadNotifications()->where('data->type', 'new_message')->count()
        );

        Sanctum::actingAs($user);

        $this->patchJson("api/conversations/{$conversation->id}/messages/read")
            ->assertOk();

        $this->assertSame(
            0,
            $user->unreadNotifications()->where('data->type', 'new_message')->count()
        );
    }

    public function test_patch_conversation_messages_read_guest_is_unauthorized(): void
    {
        [, , $conversation] = $this->conversationPair();

        $this->patchJson("api/conversations/{$conversation->id}/messages/read")->assertUnauthorized();
    }

    // GET /api/messages

    public function test_user_can_list_messages_via_messages_index(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $this->makeMessage($conversation, $user);
        $this->makeMessage($conversation, $other);

        Sanctum::actingAs($user);

        $response = $this->getJson('api/messages');

        $response->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_get_messages_guest_is_unauthorized(): void
    {
        $this->getJson('api/messages')->assertUnauthorized();
    }

    // GET /api/messages/{message}

    public function test_user_can_show_a_message(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $content = fake()->sentence();
        $message = $this->makeMessage($conversation, $other, $content);

        Sanctum::actingAs($user);

        $response = $this->getJson("api/messages/{$message->id}");

        $response->assertOk()
            ->assertJsonPath('id', $message->id)
            ->assertJsonPath('content', $content);
    }

    public function test_get_message_guest_is_unauthorized(): void
    {
        [$user, , $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        $this->getJson("api/messages/{$message->id}")->assertUnauthorized();
    }

    // POST /api/messages

    public function test_user_can_create_message_via_messages_route(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $content = fake()->sentence();

        Sanctum::actingAs($user);

        $response = $this->postJson('api/messages', [
            'conversation_id' => $conversation->id,
            'content' => $content,
        ]);

        $response->assertCreated()
            ->assertJsonPath('content', $content);

        $this->assertDatabaseHas('messages', [
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'content' => $content,
        ]);
    }

    public function test_post_messages_returns_validation_error_when_conversation_id_missing(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->postJson('api/messages', [
            'content' => fake()->sentence(),
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['conversation_id']);
    }

    public function test_post_messages_guest_is_unauthorized(): void
    {
        $this->postJson('api/messages', [
            'conversation_id' => 1,
            'content' => fake()->sentence(),
        ])->assertUnauthorized();
    }

    // PUT /api/messages/{message}

    public function test_user_can_update_their_message(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);
        $updatedContent = fake()->sentence();

        Sanctum::actingAs($user);

        $response = $this->putJson("api/messages/{$message->id}", [
            'content' => $updatedContent,
        ]);

        $response->assertOk()
            ->assertJsonPath('content', $updatedContent);
    }

    public function test_update_message_forbidden_for_non_owner(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        Sanctum::actingAs($other);

        $this->putJson("api/messages/{$message->id}", [
            'content' => fake()->sentence(),
        ])->assertForbidden();
    }

    public function test_put_message_guest_is_unauthorized(): void
    {
        [$user, , $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        $this->putJson("api/messages/{$message->id}", [
            'content' => fake()->sentence(),
        ])->assertUnauthorized();
    }

    // DELETE /api/messages/{message}

    public function test_user_can_delete_their_message(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        Sanctum::actingAs($user);

        $response = $this->deleteJson("api/messages/{$message->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('messages', ['id' => $message->id]);
    }

    public function test_delete_message_forbidden_for_non_owner(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        Sanctum::actingAs($other);

        $this->deleteJson("api/messages/{$message->id}")->assertForbidden();
    }

    public function test_delete_message_guest_is_unauthorized(): void
    {
        [$user, , $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        $this->deleteJson("api/messages/{$message->id}")->assertUnauthorized();
    }

    // PATCH /api/messages/{message}/read

    public function test_user_can_mark_message_as_read(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $other);

        Sanctum::actingAs($user);

        $response = $this->patchJson("api/messages/{$message->id}/read");

        $response->assertOk();
        $this->assertNotNull($message->fresh()->read_at);
    }

    public function test_patch_message_read_guest_is_unauthorized(): void
    {
        [$user, , $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        $this->patchJson("api/messages/{$message->id}/read")->assertUnauthorized();
    }

    // GET /api/message-attachments

    public function test_user_can_list_message_attachments(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);
        $this->makeAttachment($message, 'notes.txt');

        Sanctum::actingAs($user);

        $response = $this->getJson('api/message-attachments');

        $response->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_get_message_attachments_guest_is_unauthorized(): void
    {
        $this->getJson('api/message-attachments')->assertUnauthorized();
    }

    // GET /api/message-attachments/{messageAttachment}

    public function test_user_can_show_message_attachment(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);
        $attachment = $this->makeAttachment($message, 'details.txt');

        Sanctum::actingAs($user);

        $response = $this->getJson("api/message-attachments/{$attachment->id}");

        $response->assertOk()
            ->assertJsonPath('id', $attachment->id)
            ->assertJsonPath('file_name', 'details.txt');
    }

    public function test_show_message_attachment_forbidden_for_non_participant(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);
        $attachment = $this->makeAttachment($message, 'private.txt');
        $outsider = $this->createUser();

        Sanctum::actingAs($outsider);

        $this->getJson("api/message-attachments/{$attachment->id}")
            ->assertForbidden();
    }

    public function test_get_message_attachment_guest_is_unauthorized(): void
    {
        [$user, , $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);
        $attachment = $this->makeAttachment($message, 'guest.txt');

        $this->getJson("api/message-attachments/{$attachment->id}")->assertUnauthorized();
    }

    // POST /api/messages/{message}/attachments

    public function test_user_can_upload_message_attachment(): void
    {
        Storage::fake('public');

        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        Sanctum::actingAs($user);

        $response = $this->postJson("api/messages/{$message->id}/attachments", [
            'file' => UploadedFile::fake()->create('image.jpg', 100, 'image/jpeg'),
        ]);

        $response->assertCreated()
            ->assertJsonFragment(['file_name' => 'image.jpg']);

        $this->assertDatabaseHas('message_attachments', [
            'message_id' => $message->id,
            'file_name' => 'image.jpg',
        ]);
    }

    public function test_upload_message_attachment_rejects_invalid_file_type(): void
    {
        Storage::fake('public');

        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        Sanctum::actingAs($user);

        $this->postJson("api/messages/{$message->id}/attachments", [
            'file' => UploadedFile::fake()->create('document.pdf', 100, 'application/pdf'),
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['file']);
    }

    public function test_post_message_attachments_upload_guest_is_unauthorized(): void
    {
        [$user, , $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        $this->postJson("api/messages/{$message->id}/attachments", [
            'file' => UploadedFile::fake()->create('image.jpg', 100, 'image/jpeg'),
        ])->assertUnauthorized();
    }

    // POST /api/message-attachments

    public function test_user_can_create_message_attachment_record(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);

        Sanctum::actingAs($user);

        $response = $this->postJson('api/message-attachments', [
            'message_id' => $message->id,
            'file_path' => 'message_attachments/manual.jpg',
            'file_name' => 'manual.jpg',
            'file_type' => 'image/jpeg',
            'file_size' => 1234,
        ]);

        $response->assertCreated()
            ->assertJsonPath('file_name', 'manual.jpg');
    }

    public function test_post_message_attachments_guest_is_unauthorized(): void
    {
        $this->postJson('api/message-attachments', [
            'message_id' => 1,
            'file_path' => 'message_attachments/manual.jpg',
        ])->assertUnauthorized();
    }

    // PUT /api/message-attachments/{messageAttachment}

    public function test_user_can_update_message_attachment_record(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);
        $attachment = $this->makeAttachment($message, 'original.txt');

        Sanctum::actingAs($user);

        $response = $this->putJson("api/message-attachments/{$attachment->id}", [
            'file_name' => 'updated.txt',
            'file_path' => 'message_attachments/updated.txt',
        ]);

        $response->assertOk()
            ->assertJsonPath('file_name', 'updated.txt');
    }

    public function test_put_message_attachment_guest_is_unauthorized(): void
    {
        [$user, , $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);
        $attachment = $this->makeAttachment($message, 'original.txt');

        $this->putJson("api/message-attachments/{$attachment->id}", [
            'file_name' => 'updated.txt',
        ])->assertUnauthorized();
    }

    // DELETE /api/message-attachments/{messageAttachment}

    public function test_user_can_delete_message_attachment_record(): void
    {
        [$user, $other, $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);
        $attachment = $this->makeAttachment($message, 'delete.txt');

        Sanctum::actingAs($user);

        $response = $this->deleteJson("api/message-attachments/{$attachment->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('message_attachments', ['id' => $attachment->id]);
    }

    public function test_delete_message_attachment_guest_is_unauthorized(): void
    {
        [$user, , $conversation] = $this->conversationPair();
        $message = $this->makeMessage($conversation, $user);
        $attachment = $this->makeAttachment($message, 'delete.txt');

        $this->deleteJson("api/message-attachments/{$attachment->id}")->assertUnauthorized();
    }

    private function conversationPair(): array
    {
        $user = $this->createUser();
        $other = $this->createUser();
        $conversation = $this->createConversation([
            'user1_id' => min($user->id, $other->id),
            'user2_id' => max($user->id, $other->id),
        ]);

        return [$user, $other, $conversation];
    }

    private function makeMessage(Conversation $conversation, User $user, ?string $content = null): Message
    {
        return $this->createMessage([
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'content' => $content ?? fake()->sentence(),
        ]);
    }

    private function makeAttachment(Message $message, string $fileName): MessageAttachment
    {
        return MessageAttachment::factory()->create([
            'message_id' => $message->id,
            'file_path' => 'message_attachments/'.$fileName,
            'file_name' => $fileName,
            'file_type' => 'text/plain',
            'file_size' => 12,
        ]);
    }

    private function resetAssistantCache(): void
    {
        $reflection = new ReflectionClass(Assistant::class);
        $property = $reflection->getProperty('cachedUserId');
        $property->setAccessible(true);
        $property->setValue(null, null);
    }
}
