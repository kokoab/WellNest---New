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
            ['name' => 'Fruits', 'description' => 'Fresh and cooked dishes centered on fruit.'],
            ['name' => 'Vegetables', 'description' => 'Recipes highlighting vegetables and salads.'],
            ['name' => 'Grains', 'description' => 'Rice, oats, wheat, and other grain-based meals.'],
            ['name' => 'Protein Foods', 'description' => 'High-protein dishes across protein sources.'],
            ['name' => 'Dairy Products', 'description' => 'Recipes featuring milk, cheese, yogurt, and cream.'],
            ['name' => 'Seafood', 'description' => 'Fish, shellfish, and ocean fare.'],
            ['name' => 'Poultry', 'description' => 'Chicken, turkey, duck, and other poultry dishes.'],
            ['name' => 'Legumes', 'description' => 'Beans, lentils, chickpeas, and similar pulses.'],
            ['name' => 'Nuts and Seeds', 'description' => 'Dishes starring nuts, seeds, and nut butters.'],
            ['name' => 'Fast Food', 'description' => 'Quick-service style burgers, fries, and similar fare.'],
            ['name' => 'Desserts', 'description' => 'Sweets, cakes, pastries, and treats.'],
            ['name' => 'Beverages', 'description' => 'Drinks, smoothies, juices, and mocktails.'],
            ['name' => 'Snacks', 'description' => 'Small bites, chips, crackers, and grazing foods.'],
            ['name' => 'Spices and Condiments', 'description' => 'Sauces, spice blends, pickles, and flavor accents.'],
            ['name' => 'Processed Foods', 'description' => 'Packaged or prepared convenience foods.'],
        ];

        foreach ($categories as $data) {
            Category::firstOrCreate(
                ['name' => $data['name']],
                $data
            );
        }
    }
}
