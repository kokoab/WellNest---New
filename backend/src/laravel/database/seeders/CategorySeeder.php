<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class CategorySeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $categories = [
            ['name' => 'Vegan', 'description' => 'Plant-based recipes with no animal products.'],
            ['name' => 'Gluten-Free', 'description' => 'Recipes free of gluten-containing ingredients.'],
            ['name' => 'Pet-Safe', 'description' => 'Recipes safe for pets to consume.'],
            ['name' => 'Fruits', 'description' => 'Delicious and fresh fruit-based recipes.'],
            ['name' => 'Vegetables', 'description' => 'Healthy and nutritious vegetable recipes.'],
        ];

        foreach ($categories as $data) {
            Category::firstOrCreate(
                ['name' => $data['name']],
                $data
            );
        }
    }
}
