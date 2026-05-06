<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Database\Seeders\CategorySeeder;
use Database\Seeders\RecipeSeeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Default admin (for Docker / local dev). Change password in production.
        User::firstOrCreate(
            ['email' => 'admin@example.com'],
            [
                'first_name' => 'Admin',
                'last_name' => 'User',
                'password' => Hash::make('password'),
                'role' => 'admin',
                'status' => 'active',
                'is_admin' => true,
            ]
        );

        // Test user (regular user)
        User::firstOrCreate(
            ['email' => 'test@example.com'],
            [
                'first_name' => 'Test',
                'last_name' => 'User',
                'password' => Hash::make('password'),
                'role' => 'user',
                'status' => 'active',
                'is_admin' => false,
            ]
        );

        $this->call([
            AssistantBotSeeder::class,
            CategorySeeder::class,
            RecipeSeeder::class,
            JohnTestDemoUserSeeder::class,
        ]);
    }
}
