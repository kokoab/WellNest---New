<?php

namespace App\Console\Commands;

use App\Models\ActivityLog;
use Illuminate\Console\Command;

class PruneActivityLogs extends Command
{
    protected $signature = 'activity-logs:prune';
    protected $description = 'Delete activity logs older than 30 days';

    public function handle(): int
    {
        $count = ActivityLog::where('created_at', '<', now()->subDays(30))->delete();
        $this->info("Deleted {$count} old activity logs.");
        return self::SUCCESS;
    }
}
