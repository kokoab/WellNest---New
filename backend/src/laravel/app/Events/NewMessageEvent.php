<?php

namespace App\Events;

use App\Models\Message;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class NewMessageEvent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Message $message  // or a plain array if you prefer
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('conversation.' . $this->message->conversation_id),
        ];
    }

    /** Name of the event the frontend will listen for (e.g. "message.new"). */
    public function broadcastAs(): string
    {
        return 'message.new';
    }

    /** Payload sent to the client. */
    public function broadcastWith(): array
    {
        $this->message->load('user:id,first_name,last_name', 'attachments');
        $metadata = is_array($this->message->metadata) ? $this->message->metadata : [];
        $recipeSuggestions = $metadata['recipe_suggestions'] ?? [];

        return [
            'message' => [
                'id' => $this->message->id,
                'conversation_id' => $this->message->conversation_id,
                'user_id' => $this->message->user_id,
                'content' => $this->message->content,
                'metadata' => $this->message->metadata,
                'recipe_suggestions' => $recipeSuggestions,
                'read_at' => $this->message->read_at?->toIso8601String(),
                'created_at' => $this->message->created_at->toIso8601String(),
                'user' => [
                    'id' => $this->message->user->id,
                    'name' => $this->message->user->name,
                ],
                'attachments' => $this->message->attachments->toArray(),
            ],
        ];
    }
}
