<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Seeds a default administrator (same model as regular users: role admin, is_admin true).
 *
 * Credentials can be overridden via .env for local/Docker; set strong values in production.
 */
class AdminSeeder extends Seeder
{
    public function run(): void
    {
        $email = env('ADMIN_EMAIL', 'admin@example.com');

        User::firstOrCreate(
            ['email' => $email],
            [
                'first_name' => env('ADMIN_FIRST_NAME', 'Admin'),
                'last_name' => env('ADMIN_LAST_NAME', 'User'),
                'password' => env('ADMIN_PASSWORD', 'password'),
                'role' => 'admin',
                'status' => 'active',
                'is_admin' => true,
            ]
        );
    }
}
