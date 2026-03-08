<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RecipeRating extends Model
{
    protected $fillable = ['recipe_id', 'user_id', 'rating', 'comment'];

    protected $casts = [
        'rating' => 'integer',
    ];

    public function recipe()
    {
        return $this->belongsTo(Recipe::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
