<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

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
        return $this->belongsToMany(Ingredient::class)
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
}
