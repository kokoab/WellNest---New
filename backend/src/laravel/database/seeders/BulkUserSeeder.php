<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Creates a batch of regular (non-admin) users for demos and load testing.
 *
 * Default count can be overridden with env BULK_USERS_COUNT (e.g. 0 to skip).
 */
class BulkUserSeeder extends Seeder
{
    public function run(): void
    {
        $count = (int) env('BULK_USERS_COUNT', 500);
        if ($count <= 0) {
            return;
        }

        $regularUsersCount = User::query()
            ->where('is_admin', false)
            ->count();

        $toCreate = max(0, $count - $regularUsersCount);
        if ($toCreate > 0) {
            User::factory()
                ->count($toCreate)
                ->create();
        }

        if ($this->command) {
            $this->command->info("Regular users target: {$count}. Created: {$toCreate}.");
        }
    }
}
