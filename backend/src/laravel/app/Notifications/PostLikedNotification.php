<?php

namespace App\Notifications;

use Illuminate\Notifications\Notification;

class PostLikedNotification extends Notification
{

    public function __construct(
        public int $postId,
        public string $likerName,
        public int $actorId,
        public ?string $actorProfilePhotoUrl,
    ) {}

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toArray(object $notifiable): array
    {
        return [
            'type' => 'post_liked',
            'message' => "{$this->likerName} liked your post",
            'post_id' => $this->postId,
            'liker_name' => $this->likerName,
            'actor_id' => $this->actorId,
            'actor_profile_photo_url' => $this->actorProfilePhotoUrl,
        ];
    }
}
