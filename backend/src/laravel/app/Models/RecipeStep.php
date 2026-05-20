<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphMany;

class RecipeStep extends Model
{
    /** @use HasFactory<\Database\Factories\RecipeStepFactory> */
    use HasFactory;

    protected $fillable = [
        'recipe_id',
        'sort_order',
        'title',
        'instructions',
        'prep_time_minutes',
    ];

    protected function casts(): array
    {
        return [
            'sort_order' => 'integer',
            'prep_time_minutes' => 'integer',
        ];
    }

    public function recipe(): BelongsTo
    {
        return $this->belongsTo(Recipe::class);
    }

    /**
     * Step photos (typically one). Ordered like recipe gallery images.
     */
    public function images(): MorphMany
    {
        return $this->morphMany(Image::class, 'imageable')
            ->orderBy('sort_order')
            ->orderBy('id');
    }
}
