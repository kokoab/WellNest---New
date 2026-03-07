<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

class ContentReportedNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        public string $reportableType,
        public int $reportableId,
        public string $reporterName,
        public ?string $reason = null,
        public ?string $details = null
    ) {}

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toArray(object $notifiable): array
    {
        $typeLabel = $this->reportableType === 'recipe' ? 'Recipe' : 'Post';

        return [
            'type' => 'content_reported',
            'message' => "{$this->reporterName} reported a {$typeLabel}",
            'reportable_type' => $this->reportableType,
            'reportable_id' => $this->reportableId,
            'reporter_name' => $this->reporterName,
            'reason' => $this->reason,
            'details' => $this->details,
        ];
    }
}
