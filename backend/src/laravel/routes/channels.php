<?php

// routes/channels.php
use App\Models\Conversation;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('conversation.{conversationId}', function ($user, $conversationId) {
    $conversation = Conversation::find($conversationId);
    if (!$conversation) {
        return false;
    }
    return (int) $conversation->user1_id === (int) $user->id
        || (int) $conversation->user2_id === (int) $user->id;
});
