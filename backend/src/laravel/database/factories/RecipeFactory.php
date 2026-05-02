<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;
use App\Models\User;
use App\Models\Category;
use App\Models\Recipe;


/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Recipe>
 */
class RecipeFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $title = ucwords(rtrim(fake()->sentence(3), '.'));
        return [
            'user_id' => User::factory(),
            'category_id' => Category::factory(), 
            'title' => $title,
            'description' => fake()->paragraph,
            'instructions' => fake()->paragraph,
            'prep_time' => fake()->numberBetween(5, 60),
        ];
    }
}  
