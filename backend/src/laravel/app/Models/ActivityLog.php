<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class ActivityLog extends Model
{
    /** @use HasFactory<\Database\Factories\ActivityLogFactory> */
    use HasFactory;

    protected $fillable = [
        'user_id',
        'category',
        'action',
        'description',
        'subject_id',
        'subject_type',
        'login_type',
        'email',
        'ip_address',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function subject(): MorphTo
    {
        return $this->morphTo();
    }
}
