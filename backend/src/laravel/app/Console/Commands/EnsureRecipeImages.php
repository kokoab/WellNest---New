<?php

namespace App\Console\Commands;

use App\Models\Recipe;
use App\Support\RecipePlaceholderImage;
use Illuminate\Console\Command;

class EnsureRecipeImages extends Command
{
    protected $signature = 'recipes:ensure-images';

    protected $description = 'Add a placeholder image to every recipe that has none';

    public function handle(): int
    {
        $created = 0;
        foreach (Recipe::query()->orderBy('id')->cursor() as $recipe) {
            if (RecipePlaceholderImage::ensureForRecipe($recipe)) {
                $created++;
            }
        }

        $this->info("Added {$created} placeholder image(s). Recipes that already had images were left unchanged.");

        return self::SUCCESS;
    }
}
