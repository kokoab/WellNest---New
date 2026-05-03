<?php

// routes/channels.php
use App\Models\Conversation;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('notifications.{userId}', function ($user, $userId) {
    return (int) $user->id === (int) $userId;
});

Broadcast::channel('conversation.{conversationId}', function ($user, $conversationId) {
    $conversation = Conversation::find($conversationId);
    if (!$conversation) {
        return false;
    }
    return (int) $conversation->user1_id === (int) $user->id
        || (int) $conversation->user2_id === (int) $user->id;
});
