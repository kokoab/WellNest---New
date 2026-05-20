<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Conversation>
 */
class ConversationFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user1_id' => User::factory(),
            'user2_id' => User::factory(),
            'last_message_at' => now(),
        ];
    }
}
