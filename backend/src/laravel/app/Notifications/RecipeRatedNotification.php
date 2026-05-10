<?php

namespace App\Notifications;

use Illuminate\Notifications\Notification;

class RecipeRatedNotification extends Notification
{
    public function __construct(
        public int $recipeId,
        public string $recipeTitle,
        public string $raterName,
        public int $rating,
        public ?string $comment = null,
        public ?int $actorId = null,
        public ?string $actorProfilePhotoUrl = null,
    ) {}

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toArray(object $notifiable): array
    {
        $commentPreview = $this->comment
            ? (strlen($this->comment) > 80 ? substr($this->comment, 0, 80) . '...' : $this->comment)
            : null;

        $message = $commentPreview
            ? "{$this->raterName} commented on your recipe \"{$this->recipeTitle}\": \"{$commentPreview}\""
            : "{$this->raterName} rated your recipe \"{$this->recipeTitle}\" {$this->rating}/5";

        return [
            'type' => $commentPreview ? 'recipe_comment' : 'recipe_rated',
            'message' => $message,
            'recipe_id' => $this->recipeId,
            'recipe_title' => $this->recipeTitle,
            'rater_name' => $this->raterName,
            'rating' => $this->rating,
            'comment' => $this->comment,
            'actor_id' => $this->actorId,
            'actor_profile_photo_url' => $this->actorProfilePhotoUrl,
        ];
    }
}
