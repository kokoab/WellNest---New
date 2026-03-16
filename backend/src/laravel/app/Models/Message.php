<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Models\Conversation;
use App\Models\User;
use App\Models\MessageAttachment;

class Message extends Model
{
    //
    protected $fillable = [
        'conversation_id',
        'user_id',
        'content',
        'read_at',
        'deleted_at',
    ];

    protected $casts = [
        'created_at' => 'datetime',
        'read_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    /**
     * When message is "unsent", return placeholder for content so other user sees "{user} deleted this message".
     */
    public function getContentAttribute(?string $value): string
    {
        if (! empty($this->attributes['deleted_at'] ?? null)) {
            $user = $this->relationLoaded('user') ? $this->user : $this->user()->first();

            return ($user ? $user->first_name : 'Someone').' deleted this message';
        }

        return (string) $value;
    }

    public function attachments(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(MessageAttachment::class);
    }

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
