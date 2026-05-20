<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Models\Message;
use App\Models\User;

class Conversation extends Model
{
    /** @use HasFactory<\Database\Factories\ConversationFactory> */
    use HasFactory;

    protected $fillable = [
        'user1_id',
        'user2_id',
        'last_message_at',
    ];

    protected $casts = [
        'last_message_at' => 'datetime',
    ];

    /** Get the other participant in the conversation (for current user). */
    public function otherUser(User $currentUser): User
    {
        return (int) $this->user1_id === (int) $currentUser->id ? $this->user2 : $this->user1;
    }

    public function user1(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function user2(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class);
    }
}
