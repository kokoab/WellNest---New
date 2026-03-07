<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

class CommentReceivedNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        public int $postId,
        public string $commenterName,
        public string $commentPreview,
        public ?int $recipeId = null
    ) {}

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toArray(object $notifiable): array
    {
        $preview = strlen($this->commentPreview) > 50
            ? substr($this->commentPreview, 0, 50) . '...'
            : $this->commentPreview;

        return [
            'type' => 'comment_received',
            'message' => "{$this->commenterName} commented on your post: \"{$preview}\"",
            'post_id' => $this->postId,
            'recipe_id' => $this->recipeId,
            'commenter_name' => $this->commenterName,
        ];
    }
}
