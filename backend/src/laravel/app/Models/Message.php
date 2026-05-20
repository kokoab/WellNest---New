<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Models\Conversation;
use App\Models\User;
use App\Models\MessageAttachment;

class Message extends Model
{
    /** @use HasFactory<\Database\Factories\MessageFactory> */
    use HasFactory;

    protected $fillable = [
        'conversation_id',
        'user_id',
        'content',
        'metadata',
        'read_at',
    ];

    protected $casts = [
        'created_at' => 'datetime',
        'read_at' => 'datetime',
        'metadata' => 'array',
    ];

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
