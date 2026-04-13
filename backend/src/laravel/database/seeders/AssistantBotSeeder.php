<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AssistantBotSeeder extends Seeder
{
    /**
     * System user used as the "other participant" in assistant DM threads.
     */
    public function run(): void
    {
        User::firstOrCreate(
            ['email' => config('assistant.bot_email', 'assistant@wellnest.local')],
            [
                'first_name' => 'WellNest',
                'last_name' => 'Assistant',
                'password' => Hash::make(str()->random(64)),
                'role' => 'user',
                'status' => 'active',
                'is_admin' => false,
            ]
        );
    }
}
