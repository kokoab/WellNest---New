<?php

namespace Database\Seeders;

use App\Models\Recipe;
use App\Support\RecipePlaceholderImage;
use Illuminate\Database\Seeder;

/**
 * Ensures every recipe has at least one image (SVG placeholder on public disk).
 */
class RecipeImageSeeder extends Seeder
{
    public function run(): void
    {
        $created = 0;
        foreach (Recipe::query()->orderBy('id')->cursor() as $recipe) {
            if (RecipePlaceholderImage::ensureForRecipe($recipe)) {
                $created++;
            }
        }

        if ($this->command) {
            $this->command->info("Recipe images: added {$created} placeholder(s); skipped recipes that already had images.");
        }
    }
}
