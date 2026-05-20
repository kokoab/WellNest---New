<?php

namespace Database\Factories;

use App\Models\Recipe;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Report>
 */
class ReportFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'reportable_type' => Recipe::class,
            'reportable_id' => Recipe::factory(),
            'reason' => fake()->words(3, true),
            'status' => 'pending',
        ];
    }
}
