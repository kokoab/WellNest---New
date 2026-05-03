<?php

namespace App\Jobs;

use App\Events\UnreadNotificationBadgeUpdated;
use App\Events\AssistantStreamEvent;
use App\Events\NewMessageEvent;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\Notifications\NewMessageNotification;
use App\Services\OllamaChatService;
use App\Support\Assistant;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class GenerateAssistantReply
{
    use Dispatchable, SerializesModels;

    public function __construct(
        public int $conversationId,
        public int $triggerUserMessageId,
    ) {}

    public function handle(OllamaChatService $ollama): void
    {
        $botId = Assistant::botUserId();
        if (! $botId) {
            return;
        }

        $conversation = Conversation::find($this->conversationId);
        if (! $conversation || ! Assistant::isConversationWithAssistant((int) $conversation->user1_id, (int) $conversation->user2_id)) {
            return;
        }

        $trigger = Message::find($this->triggerUserMessageId);
        if (! $trigger || (int) $trigger->conversation_id !== $this->conversationId) {
            return;
        }

        $since = now()->subDays((int) config('assistant.history_days', 7));

        $history = Message::query()
            ->where('conversation_id', $conversation->id)
            ->where('created_at', '>=', $since)
            ->with(['user:id,first_name,last_name'])
            ->orderBy('created_at', 'asc')
            ->get();

        $messages = [];

        $messages[] = [
            'role' => 'system',
            'content' => (string) config('assistant.system_prompt'),
        ];

        foreach ($history as $msg) {
            if ((int) $msg->user_id === $botId) {
                $messages[] = [
                    'role' => 'assistant',
                    'content' => (string) $msg->content,
                ];
            } else {
                $messages[] = [
                    'role' => 'user',
                    'content' => (string) $msg->content,
                ];
            }
        }

        $streamId = (string) Str::uuid();
        $full = '';

        try {
            $full = $ollama->streamChat($messages, function (string $accumulated, string $delta) use ($streamId, $conversation) {
                broadcast(new AssistantStreamEvent(
                    $conversation->id,
                    $streamId,
                    $delta,
                    $accumulated,
                    false,
                ));
            });
        } catch (\Throwable $e) {
            Log::error('Assistant Ollama stream failed', ['exception' => $e->getMessage()]);
            $full = 'Sorry, I could not reach the assistant right now. Please try again in a moment.';
        }

        $full = trim($full);
        if ($full === '') {
            $full = 'I did not get a response. Please try again.';
        }

        broadcast(new AssistantStreamEvent(
            $conversation->id,
            $streamId,
            '',
            $full,
            true,
        ));

        $botUser = User::find($botId);
        $human = $conversation->user1_id === $botId ? $conversation->user2 : $conversation->user1;

        $assistantMessage = Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $botId,
            'content' => $full,
        ]);

        $conversation->update(['last_message_at' => $assistantMessage->created_at]);

        if ($human instanceof User) {
            $human->notify(new NewMessageNotification(
                $conversation->id,
                $assistantMessage->id,
                $botUser?->name ?? 'WellNest Assistant',
                strlen($full) > 120 ? substr($full, 0, 120).'...' : $full
            ));
            event(new UnreadNotificationBadgeUpdated($human->id));
        }

        $assistantMessage->load('user:id,first_name,last_name,profile_photo_url', 'attachments');
        broadcast(new NewMessageEvent($assistantMessage));
    }
}
