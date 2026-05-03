<?php

namespace Database\Factories;

use App\Models\Ingredient;
use App\Models\RecipeIngredient;
use Illuminate\Database\Eloquent\Factories\Factory;
use App\Models\Recipe;

/**
 * @extends Factory<RecipeIngredient>
 */
class RecipeIngredientFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
    */
    public function definition(): array
    {
        return [
            'recipe_id' => Recipe::factory(),
            'ingredient_id' => Ingredient::factory(),
            'quantity' => rand(1,3),
            'unit' => rand(1,3),
        ];
    }
}
