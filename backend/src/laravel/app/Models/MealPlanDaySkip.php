<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MealPlanDaySkip extends Model
{
    protected $table = 'meal_plan_day_skips';

    protected $fillable = [
        'user_id',
        'skipped_date',
    ];

    protected function casts(): array
    {
        return [
            'skipped_date' => 'date',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
