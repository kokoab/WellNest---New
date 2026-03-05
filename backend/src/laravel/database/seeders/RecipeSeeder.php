<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class RecipeSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $user = \App\Models\User::first();
        if (!$user) {
            $this->command->warn('No user found. Run User seeder or migrations first.');
            return;
        }

        $vegan = \App\Models\Category::where('name', 'Vegan')->first();
        $glutenFree = \App\Models\Category::where('name', 'Gluten-Free')->first();
        $petSafe = \App\Models\Category::where('name', 'Pet-Safe')->first();

        if (!$vegan) {
            $this->command->warn('No categories found. Run CategorySeeder first.');
            return;
        }

        $recipes = [
            [
                'user_id'      => $user->id,
                'category_id'  => $vegan->id,
                'title'        => 'Simple Avocado Toast',
                'instructions' => 'Mash avocado. Toast bread. Spread avocado on toast. Add salt and pepper.',
                'prep_time'    => 5,
            ],
            [
                'user_id'      => $user->id,
                'category_id'  => $vegan->id,
                'title'        => 'Overnight Oats',
                'instructions' => 'Mix oats, plant milk, and chia seeds. Refrigerate overnight. Top with fruit.',
                'prep_time'    => 10,
            ],
            [
                'user_id'      => $user->id,
                'category_id'  => $glutenFree?->id ?? $vegan->id,
                'title'        => 'Roasted Vegetables',
                'instructions' => 'Chop vegetables. Toss with olive oil and herbs. Roast at 400°F for 25 minutes.',
                'prep_time'    => 30,
            ],
        ];

        foreach ($recipes as $data) {
            \App\Models\Recipe::firstOrCreate(
                ['title' => $data['title'], 'user_id' => $data['user_id']],
                $data
            );
        }
    }
}
