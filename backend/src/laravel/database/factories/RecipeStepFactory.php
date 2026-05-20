<?php

namespace Database\Factories;

use App\Models\Recipe;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\RecipeStep>
 */
class RecipeStepFactory extends Factory
{
    public function definition(): array
    {
        return [
            'recipe_id' => Recipe::factory()->withoutIngredients(),
            'sort_order' => 0,
            'title' => fake()->words(3, true),
            'instructions' => fake()->sentence(),
            'prep_time_minutes' => fake()->numberBetween(1, 30),
        ];
    }
}
