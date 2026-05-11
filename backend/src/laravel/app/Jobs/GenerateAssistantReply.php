<?php

namespace App\Jobs;

use App\Events\UnreadNotificationBadgeUpdated;
use App\Events\AssistantStreamEvent;
use App\Events\NewMessageEvent;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\Notifications\NewMessageNotification;
use App\Services\AssistantRecipeCatalogService;
use App\Services\OllamaChatService;
use App\Support\Assistant;
use App\Support\AssistantRecipeCatalogMatcher;
use App\Support\AssistantReplyRecipeParser;
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

    public function handle(OllamaChatService $ollama, AssistantRecipeCatalogService $recipeCatalog): void
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

        $catalogBundle = $recipeCatalog->resolveCatalogForAssistant((string) $trigger->content);
        /** @var \Illuminate\Support\Collection<int, \App\Models\Recipe> $catalog */
        $catalog = $catalogBundle['catalog'];
        $foodRelated = $catalogBundle['food_related'];
        $intent = (string) ($catalogBundle['intent'] ?? 'general');

        $system = (string) config('assistant.system_prompt');
        if ($foodRelated && $catalog->isNotEmpty()) {
            $lines = $catalog->map(static fn ($r) => '- ['.$r->id.'] '.$r->title)->implode("\n");
            $system .= "\n\n## Exclusive WellNest recipe catalog for this reply\nYou MUST ONLY name dishes using titles copied exactly from this list (these are real recipes in the app).\n".$lines;
            $system .= "\n\nWhen you suggest food from this catalog, end your reply with exactly one final line:\nRECIPES: id1,id2,id3\nUse up to three numeric ids from the brackets. Never invent ids or dishes outside this list.";
        } elseif ($foodRelated && $catalog->isEmpty()) {
            $system .= "\n\nThere are no matching recipes in WellNest for this question. Do not name specific dishes or recipes. Briefly encourage browsing Discover in the app. Do not add a RECIPES line.";
        } else {
            $system .= "\n\nThis user message is not asking for meals or recipes. Do not suggest recipes or name specific dishes. Do not add a RECIPES line.";
        }

        $messages = [];

        $messages[] = [
            'role' => 'system',
            'content' => $system,
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

        if (str_starts_with($intent, 'ranking:')) {
            $full = $this->rankingReplyFromCatalog($intent, $catalog);
        } else {
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
        }

        $full = trim($full);
        if ($full === '') {
            $full = 'I did not get a response. Please try again.';
        }

        [$cleanContent, $parsedIds] = AssistantReplyRecipeParser::splitContentAndRecipeIds($full);
        $allowedIds = $catalog->pluck('id')->flip();
        $validatedIds = [];
        foreach ($parsedIds as $id) {
            if ($allowedIds->has($id)) {
                $validatedIds[] = $id;
            }
        }
        $validatedIds = array_slice(array_unique($validatedIds), 0, 3);

        $recipeSuggestions = [];
        foreach ($validatedIds as $id) {
            $row = $catalog->firstWhere('id', $id);
            if ($row !== null) {
                $recipeSuggestions[] = [
                    'id' => $row->id,
                    'title' => $row->title,
                ];
            }
        }

        $finalText = $cleanContent !== '' ? $cleanContent : $full;
        $maxLinks = max(1, min(8, (int) config('assistant.recipe_suggestion_links_max', 5)));

        if ($foodRelated && $catalog->isNotEmpty()) {
            $recipeSuggestions = AssistantRecipeCatalogMatcher::supplementFromTitleMatches(
                $finalText,
                $catalog,
                $recipeSuggestions,
                $maxLinks,
            );
        }

        $metadata = $recipeSuggestions !== [] ? ['recipe_suggestions' => $recipeSuggestions] : null;

        broadcast(new AssistantStreamEvent(
            $conversation->id,
            $streamId,
            '',
            $finalText,
            true,
            $recipeSuggestions,
        ));

        $botUser = User::find($botId);
        $human = $conversation->user1_id === $botId ? $conversation->user2 : $conversation->user1;

        $assistantMessage = Message::create([
            'conversation_id' => $conversation->id,
            'user_id' => $botId,
            'content' => $finalText,
            'metadata' => $metadata,
        ]);

        $conversation->update(['last_message_at' => $assistantMessage->created_at]);

        if ($human instanceof User) {
            $human->notify(new NewMessageNotification(
                $conversation->id,
                $assistantMessage->id,
                $botUser?->name ?? 'WellNest Assistant',
                strlen($finalText) > 120 ? substr($finalText, 0, 120).'...' : $finalText,
                (int) ($botUser?->id ?? 0),
                $botUser?->profile_photo_url,
                true,
            ));
            event(new UnreadNotificationBadgeUpdated($human->id));
        }

        $assistantMessage->load('user:id,first_name,last_name,profile_photo_url', 'attachments');
        broadcast(new NewMessageEvent($assistantMessage));
    }

    private function rankingReplyFromCatalog(string $intent, \Illuminate\Support\Collection $catalog): string
    {
        if ($catalog->isEmpty()) {
            return 'The recipe leaderboard does not have enough ratings or views yet. Check back after more recipes get activity.';
        }

        $mode = str_replace('ranking:', '', $intent);
        $label = match ($mode) {
            'ratings' => 'top rated',
            'views' => 'most popular',
            default => 'top ranked',
        };

        $top = $catalog->take(3)->values();
        $titles = $top->pluck('title')->map(fn ($title) => (string) $title)->all();
        $ids = $top->pluck('id')->map(fn ($id) => (int) $id)->all();

        if (count($titles) === 1) {
            return 'The current '.$label.' recipe is '.$titles[0].'.'."\nRECIPES: ".implode(',', $ids);
        }

        $last = array_pop($titles);

        return 'The current '.$label.' recipes are '.implode(', ', $titles).', and '.$last.'.'."\nRECIPES: ".implode(',', $ids);
    }
}
