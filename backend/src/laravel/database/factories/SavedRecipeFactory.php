<?php

namespace Database\Factories;

use App\Models\Recipe;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\SavedRecipe>
 */
class SavedRecipeFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'recipe_id' => Recipe::factory(),
        ];
    }
}
