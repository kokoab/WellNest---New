<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\MessageAttachment;
use App\Notifications\NewMessageNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ConversationMessagingTest extends TestCase
{
    use RefreshDatabase;

    public function test_assistant_endpoint_returns_service_available(): void
    {
        $user = $this->createUser();
        $bot = $this->createUser([
            'email' => config('assistant.bot_email'),
            'first_name' => 'WellNest',
            'last_name' => 'Assistant',
        ]);
        config(['assistant.bot_user_id' => $bot->id]);
        Sanctum::actingAs($user);

        $response = $this->getJson('api/conversations/assistant');

        $response->assertOk()
            ->assertJsonFragment([
                'is_assistant' => true,
            ]);
    }

    public function test_user_can_show_their_conversation(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        Sanctum::actingAs($user);

        $response = $this->getJson("api/conversations/{$conversation->id}");

        $response->assertOk()
            ->assertJsonPath('conversation.id', $conversation->id);
    }

    public function test_user_can_update_their_conversation(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        Sanctum::actingAs($user);

        $response = $this->putJson("api/conversations/{$conversation->id}", []);

        $response->assertOk()
            ->assertJsonPath('id', $conversation->id);
    }

    public function test_user_can_delete_their_conversation(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        Sanctum::actingAs($user);

        $response = $this->deleteJson("api/conversations/{$conversation->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('conversations', ['id' => $conversation->id]);
    }

    public function test_user_can_list_messages_via_messages_index(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $this->createMessage($conversation, $user, 'Hello');
        $this->createMessage($conversation, $otherUser, 'Hi');

        Sanctum::actingAs($user);

        $response = $this->getJson('api/messages');

        $response->assertOk()
            ->assertJsonCount(2, 'data');
    }

    public function test_user_can_show_a_message(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $message = $this->createMessage($conversation, $otherUser, 'Hello there');

        Sanctum::actingAs($user);

        $response = $this->getJson("api/messages/{$message->id}");

        $response->assertOk()
            ->assertJsonPath('id', $message->id)
            ->assertJsonPath('content', 'Hello there');
    }

    public function test_user_can_create_message_via_messages_route(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        Sanctum::actingAs($user);

        $response = $this->postJson('api/messages', [
            'conversation_id' => $conversation->id,
            'content' => 'Standalone message',
        ]);

        $response->assertCreated()
            ->assertJsonPath('content', 'Standalone message');

        $this->assertDatabaseHas('messages', [
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'content' => 'Standalone message',
        ]);
    }

    public function test_user_can_update_their_message(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $message = $this->createMessage($conversation, $user, 'Original');

        Sanctum::actingAs($user);

        $response = $this->putJson("api/messages/{$message->id}", [
            'content' => 'Updated message',
        ]);

        $response->assertOk()
            ->assertJsonPath('content', 'Updated message');
    }

    public function test_user_can_delete_their_message(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $message = $this->createMessage($conversation, $user, 'Delete me');

        Sanctum::actingAs($user);

        $response = $this->deleteJson("api/messages/{$message->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('messages', ['id' => $message->id]);
    }

    public function test_user_can_mark_message_as_read(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $message = $this->createMessage($conversation, $otherUser, 'Unread');

        Sanctum::actingAs($user);

        $response = $this->patchJson("api/messages/{$message->id}/read");

        $response->assertOk();
        $this->assertNotNull($message->fresh()->read_at);
    }

    public function test_user_can_mark_entire_conversation_as_read(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $this->createMessage($conversation, $otherUser, 'Unread one');
        $this->createMessage($conversation, $otherUser, 'Unread two');

        Sanctum::actingAs($user);

        $response = $this->patchJson("api/conversations/{$conversation->id}/messages/read");

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Marked as read']);
    }

    public function test_mark_conversation_as_read_clears_new_message_notifications(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $this->createMessage($conversation, $otherUser, 'Ping');

        $user->notify(new NewMessageNotification(
            $conversation->id,
            1,
            $otherUser->name,
            'Ping',
            $otherUser->id,
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

    public function test_user_can_list_message_attachments(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $message = $this->createMessage($conversation, $user, 'Attachment message');
        $this->createAttachment($message, 'notes.txt');

        Sanctum::actingAs($user);

        $response = $this->getJson('api/message-attachments');

        $response->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_user_can_show_message_attachment(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $message = $this->createMessage($conversation, $user, 'Attachment message');
        $attachment = $this->createAttachment($message, 'details.txt');

        Sanctum::actingAs($user);

        $response = $this->getJson("api/message-attachments/{$attachment->id}");

        $response->assertOk()
            ->assertJsonPath('id', $attachment->id)
            ->assertJsonPath('file_name', 'details.txt');
    }

    public function test_user_can_upload_message_attachment(): void
    {
        Storage::fake('public');

        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $message = $this->createMessage($conversation, $user, 'Upload attachment');

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

    public function test_user_can_create_message_attachment_record(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $message = $this->createMessage($conversation, $user, 'Create attachment');

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

    public function test_user_can_update_message_attachment_record(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $message = $this->createMessage($conversation, $user, 'Update attachment');
        $attachment = $this->createAttachment($message, 'original.txt');

        Sanctum::actingAs($user);

        $response = $this->putJson("api/message-attachments/{$attachment->id}", [
            'file_name' => 'updated.txt',
            'file_path' => 'message_attachments/updated.txt',
        ]);

        $response->assertOk()
            ->assertJsonPath('file_name', 'updated.txt');
    }

    public function test_user_can_delete_message_attachment_record(): void
    {
        [$user, $otherUser, $conversation] = $this->createConversationPair();
        $message = $this->createMessage($conversation, $user, 'Delete attachment');
        $attachment = $this->createAttachment($message, 'delete.txt');

        Sanctum::actingAs($user);

        $response = $this->deleteJson("api/message-attachments/{$attachment->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('message_attachments', ['id' => $attachment->id]);
    }

    private function createConversationPair(): array
    {
        $user = $this->createUser(['email' => 'chat-user@example.com']);
        $otherUser = $this->createUser(['email' => 'chat-other@example.com']);
        $conversation = Conversation::create([
            'user1_id' => $user->id,
            'user2_id' => $otherUser->id,
        ]);

        return [$user, $otherUser, $conversation];
    }

    private function createMessage(Conversation $conversation, $user, string $content): Message
    {
        return Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'content' => $content,
        ]);
    }

    private function createAttachment(Message $message, string $fileName): MessageAttachment
    {
        return MessageAttachment::create([
            'message_id' => $message->id,
            'file_path' => 'message_attachments/' . $fileName,
            'file_name' => $fileName,
            'file_type' => 'text/plain',
            'file_size' => 12,
        ]);
    }
}
