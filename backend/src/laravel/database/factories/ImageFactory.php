<?php

namespace Database\Factories;

use App\Models\Recipe;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Image>
 */
class ImageFactory extends Factory
{
    public function definition(): array
    {
        return [
            'path' => 'images/'.fake()->uuid().'.jpg',
            'sort_order' => 0,
            'imageable_type' => Recipe::class,
            'imageable_id' => Recipe::factory()->withoutIngredients(),
        ];
    }
}
