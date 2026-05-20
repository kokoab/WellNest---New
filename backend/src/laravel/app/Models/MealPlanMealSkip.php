<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MealPlanMealSkip extends Model
{
    /** @use HasFactory<\Database\Factories\MealPlanMealSkipFactory> */
    use HasFactory;

    protected $table = 'meal_plan_meal_skips';

    protected $fillable = [
        'user_id',
        'skipped_date',
        'meal_slot',
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
