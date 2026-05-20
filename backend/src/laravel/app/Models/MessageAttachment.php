<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Models\Message;

class MessageAttachment extends Model
{
    /** @use HasFactory<\Database\Factories\MessageAttachmentFactory> */
    use HasFactory;

    protected $fillable = [
        'message_id',
        'file_path',
        'file_name',
        'file_type',
        'file_size',
    ];

    public function message(): BelongsTo
    {
        return $this->belongsTo(Message::class);
    }
}
