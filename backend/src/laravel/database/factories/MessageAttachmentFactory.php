<?php

namespace Database\Factories;

use App\Models\Message;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\MessageAttachment>
 */
class MessageAttachmentFactory extends Factory
{
    public function definition(): array
    {
        $word = fake()->word();

        return [
            'message_id' => Message::factory(),
            'file_path' => 'attachments/'.$word.'.pdf',
            'file_name' => $word.'.pdf',
            'file_type' => 'application/pdf',
            'file_size' => (string) fake()->numberBetween(1000, 500000),
        ];
    }
}
