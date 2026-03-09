<?php

namespace App\Notifications;

use Illuminate\Notifications\Notification;

class RecipeLikedNotification extends Notification
{

    public function __construct(
        public int $recipeId,
        public string $recipeTitle,
        public string $likerName
    ) {}

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toArray(object $notifiable): array
    {
        return [
            'type' => 'recipe_liked',
            'message' => "{$this->likerName} liked your recipe \"{$this->recipeTitle}\"",
            'recipe_id' => $this->recipeId,
            'recipe_title' => $this->recipeTitle,
            'liker_name' => $this->likerName,
        ];
    }
}
