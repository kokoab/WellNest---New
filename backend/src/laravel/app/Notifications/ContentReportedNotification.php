<?php

namespace App\Notifications;

use Illuminate\Notifications\Notification;

class ContentReportedNotification extends Notification
{

    public function __construct(
        public string $reportableType,
        public int $reportableId,
        public string $reporterName,
        public ?string $reason = null,
        public ?string $details = null,
        public ?int $reporterId = null,
        public ?string $reporterProfilePhotoUrl = null,
    ) {}

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toArray(object $notifiable): array
    {
        $typeLabel = $this->reportableType === 'recipe' ? 'Recipe' : ($this->reportableType === 'user' ? 'User' : ($this->reportableType === 'post' ? 'Post' : 'Unknown'));

        return [
            'type' => 'content_reported',
            'message' => "{$this->reporterName} reported a {$typeLabel}",
            'reportable_type' => $this->reportableType,
            'reportable_id' => $this->reportableId,
            'reporter_name' => $this->reporterName,
            'reason' => $this->reason,
            'details' => $this->details,
            'actor_id' => $this->reporterId,
            'actor_profile_photo_url' => $this->reporterProfilePhotoUrl,
        ];
    }
}
