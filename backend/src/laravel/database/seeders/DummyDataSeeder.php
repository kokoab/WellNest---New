<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Vote;
use App\Models\Post;
use App\Models\Recipe;


class DummyDataSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $users = User::factory()->count(200)->create();
        $categories = Category::factory()->count(10)->create();


        for ($i = 0; $i < 1000; $i++) {
            $user = $users->random();

            $choice = rand(1,3);

            match($choice) {
                1 => Post::factory()->create(['user_id' => $user->id]),
                2 => Recipe::factory()->create([
                    'user_id' => $user->id,
                    'category_id' => $categories->random()->id,
                    ]),
                3 => Vote::factory()->create(['user_id' => $user->id]),
            };
        }



    }
}
