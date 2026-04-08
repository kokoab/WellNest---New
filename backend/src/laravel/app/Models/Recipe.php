<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Model;
use App\Models\RecipeView;
use App\Models\Category;
use App\Models\Ingredient;
use App\Models\Image;
use App\Models\Vote;
use App\Models\Post;
use App\Models\Report;
use App\Models\RecipeRating;
use App\Models\User;

class Recipe extends Model
{
    //
    protected $fillable = [
        'user_id',
        'category_id',
        'title',
        'instructions',
        'prep_time',
    ];

    public function views(): HasMany {
        return $this->hasMany(RecipeView::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function ingredients()
    {
        return $this->belongsToMany(Ingredient::class, 'recipe_ingredients')
            ->withPivot('quantity', 'unit')
            ->withTimestamps();
    }
    public function images()
    {
        return $this->morphMany(Image::class, 'imageable');
    }
    public function votes()
    {
        return $this->morphMany(Vote::class, 'votable');
    }
    public function posts()
    {
        return $this->hasMany(Post::class);
    }

    public function reports()
    {
        return $this->morphMany(Report::class, 'reportable');
    }

    public function ratings()
    {
        return $this->hasMany(RecipeRating::class);
    }
    public function savedRecipes()
    {
        return $this->belongsToMany(User::class, 'saved_recipes')
            ->withTimestamps();
    }
}
