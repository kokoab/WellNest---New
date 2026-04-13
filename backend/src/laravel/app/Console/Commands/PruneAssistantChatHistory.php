<?php

namespace App\Console\Commands;

use App\Models\Message;
use App\Support\Assistant;
use Illuminate\Console\Command;

class PruneAssistantChatHistory extends Command
{
    protected $signature = 'assistant:prune-history';

    protected $description = 'Delete assistant conversation messages older than the configured retention period';

    public function handle(): int
    {
        $botId = Assistant::botUserId();
        if (! $botId) {
            $this->warn('Assistant bot user is not configured.');

            return self::SUCCESS;
        }

        $days = (int) config('assistant.history_days', 7);
        $cutoff = now()->subDays($days);

        $deleted = Message::query()
            ->whereHas('conversation', function ($q) use ($botId) {
                $q->where('user1_id', $botId)->orWhere('user2_id', $botId);
            })
            ->where('created_at', '<', $cutoff)
            ->delete();

        $this->info("Deleted {$deleted} message(s) older than {$days} day(s).");

        return self::SUCCESS;
    }
}
