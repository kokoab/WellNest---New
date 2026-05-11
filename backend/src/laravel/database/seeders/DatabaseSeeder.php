<?php

namespace Database\Seeders;

use App\Models\User;
use Database\Seeders\CategorySeeder;
use Database\Seeders\Concerns\SeedsHistoryRange;
use Database\Seeders\DummyDataSeeder;
use Database\Seeders\RecipeSeeder;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use SeedsHistoryRange;
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

        // Earliest possible recipe timestamps align with the catalog owner (test user).
        $adminJoined = $this->historyStartUtc()->addHour();
        $testJoined = $this->historyStartUtc();
        DB::table('users')->where('email', 'admin@example.com')->update([
            'created_at' => $adminJoined->toDateTimeString(),
            'updated_at' => $adminJoined->toDateTimeString(),
        ]);
        DB::table('users')->where('email', 'test@example.com')->update([
            'created_at' => $testJoined->toDateTimeString(),
            'updated_at' => $testJoined->toDateTimeString(),
        ]);

        $this->call([
            AssistantBotSeeder::class,
            CategorySeeder::class,
            RecipeSeeder::class,
            DummyDataSeeder::class,
        ]);
    }
}
