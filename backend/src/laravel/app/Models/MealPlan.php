<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MealPlan extends Model
{
    /** @use HasFactory<\Database\Factories\MealPlanFactory> */
    use HasFactory;

    protected $table = 'meal_plans';

    protected $fillable = [
        'user_id',
        'recipe_id',
        'planned_date',
        'meal_slot',
    ];

    protected function casts(): array
    {
        return [
            'planned_date' => 'date',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function recipe(): BelongsTo
    {
        return $this->belongsTo(Recipe::class);
    }
}
