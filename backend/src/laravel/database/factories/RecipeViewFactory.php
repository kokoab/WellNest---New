<?php

namespace Database\Factories;

use App\Models\Recipe;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\RecipeView>
 */
class RecipeViewFactory extends Factory
{
    public function definition(): array
    {
        return [
            'recipe_id' => Recipe::factory(),
            'user_id' => User::factory(),
            'view_date' => now()->toDateString(),
        ];
    }
}
