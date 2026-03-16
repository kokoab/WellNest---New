<?php

namespace App\Notifications;

use Illuminate\Notifications\Notification;

class NewMessageNotification extends Notification
{
    public function __construct(
        public int $conversationId,
        public int $messageId,
        public string $senderName,
        public string $content
    ) {}

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toArray(object $notifiable): array
    {
        $preview = strlen($this->content) > 50
            ? substr($this->content, 0, 50) . '...'
            : $this->content;

        return [
            'type' => 'new_message',
            'message' => "{$this->senderName}: {$preview}",
            'conversation_id' => $this->conversationId,
            'message_id' => $this->messageId,
            'sender_name' => $this->senderName,
            'body_preview' => $preview,
        ];
    }
}
