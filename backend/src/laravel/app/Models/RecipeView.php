<?php

namespace App\Models;

use App\Models\User;
use App\Models\Recipe;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RecipeView extends Model
{
    /** @use HasFactory<\Database\Factories\RecipeViewFactory> */
    use HasFactory;

    protected $fillable =[
        'recipe_id',
        'user_id',
        'view_date'
    ];

    public function user(): BelongsTo {
        return $this->belongsTo(User::class);
    }

    public function recipe(): BelongsTo {
        return $this->belongsTo(Recipe::class);
    }
}
