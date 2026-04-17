<?php

namespace Tests\Unit;

use App\Jobs\GenerateAssistantReply;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\Services\OllamaChatService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AssistantConfigTest extends TestCase
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
            'status' => 'active',
            'is_admin' => false,
        ], $overrides));
    }

    public function test_chatbot_creates_a_reply_message(): void
    {
        $bot = $this->createUser([
            'first_name' => 'WellNest',
            'last_name' => 'Assistant',
            'email' => 'assistant@wellnest.local',
        ]);
        $human = $this->createUser([
            'first_name' => 'Jane',
            'last_name' => 'Doe',
            'email' => 'jane@example.com',
        ]);

        $conversation = Conversation::create([
            'user1_id' => $human->id,
            'user2_id' => $bot->id,
            'last_message_at' => now(),
        ]);

        $trigger = Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $human->id,
            'content' => 'Hi assistant, suggest a healthy breakfast.',
        ]);

        $ollama = app(OllamaChatService::class);

        $job = new GenerateAssistantReply($conversation->id, $trigger->id);
        $job->handle($ollama);

        $assistantReply = Message::query()
            ->where('conversation_id', $conversation->id)
            ->where('user_id', $bot->id)
            ->latest('id')
            ->first();

        $this->assertNotNull($assistantReply);
        $this->assertNotSame('', trim((string) $assistantReply->content));
    }
}

