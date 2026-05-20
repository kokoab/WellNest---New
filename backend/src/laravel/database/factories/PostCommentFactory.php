<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;
use App\Models\User;
use App\Models\Post;
use App\Models\PostComment;


/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\PostComment>
 */
class PostCommentFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'post_id' => Post::factory(),
            'comment' => fake()->paragraph(),
            'image_url' => fake()->imageUrl(),
        ];
    }
}
