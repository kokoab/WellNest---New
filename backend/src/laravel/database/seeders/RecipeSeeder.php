<?php

namespace Database\Seeders;

use App\Models\Recipe;
use App\Models\RecipeStep;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class RecipeSeeder extends Seeder
{
    public function run(): void
    {
        $user = \App\Models\User::where('email', 'test@example.com')->first()
            ?? \App\Models\User::first();
        if (! $user) {
            $this->command->warn('No user found. Run DatabaseSeeder first.');
            return;
        }

        $categoriesData = [
            'Vegan' => [
                'simple-avocado-toast.jpg',
                'overnight-oats-with-chia.jpg',
                'mediterranean-chickpea-bowl.jpg',
                'ginger-turmeric-lentil-soup.jpg',
                'thai-style-tofu-lettuce-cups.jpg',
                'cashew-alfredo-with-broccoli.jpg',
                'smoky-bbq-jackfruit-sliders.jpg',
                'wild-mushroom-herb-risotto.jpg',
                'coconut-vegetable-curry.jpg',
                'chocolate-avocado-pudding.jpg',
            ],
            'Gluten-Free' => [
                'baked-lemon-herb-salmon.jpg',
                'sheet-pan-mediterranean-vegetables.jpg',
                'corn-tortilla-chicken-tacos.jpg',
                'quinoa-tabbouleh-salad.jpg',
                'flourless-chocolate-almond-cake.jpg',
                'garlic-butter-shrimp-with-zoodles.jpg',
                'herb-crusted-pork-tenderloin.jpg',
                'thai-beef-lettuce-wraps.jpg',
                'creamy-polenta-with-ratatouille.jpg',
                'crispy-parmesan-potato-wedges.jpg',
            ],
            'Pet-Safe' => [
                'xylitol-free-peanut-butter-pumpkin-bites.jpg',
                'plain-chicken-and-rice-pup-bowl.jpg',
                'carrot-and-apple-horse-cookies.jpg',
                'frozen-yogurt-blueberry-drops.jpg',
                'sweet-potato-chews.jpg',
                'tuna-cat-crumbles.jpg',
                'banana-oat-dog-biscuits.jpg',
                'egg-and-spinach-mash.jpg',
                'salmon-skin-cracklings.jpg',
                'rice-flour-baby-biscuits.jpg',
            ],
            'Fruits' => [
                'summer-peach-caprese-skewers.jpg',
                'berry-citrus-salad-with-mint.jpg',
                'grilled-pineapple-with-cinnamon.jpg',
                'apple-cheddar-walnut-salad.jpg',
                'mango-sticky-rice.jpg',
                'fig-and-ricotta-toast.jpg',
                'watermelon-feta-mint-salad.jpg',
                'baked-cinnamon-pears.jpg',
                'tropical-smoothie-parfait.jpg',
                'cherry-compote-over-yogurt.jpg',
            ],
            'Vegetables' => [
                'roasted-brussels-sprouts-with-bacon.jpg',
                'classic-minestrone.jpg',
                'garlic-green-beans-almondine.jpg',
                'stuffed-portobello-mushrooms.jpg',
                'creamy-cauliflower-soup.jpg',
                'asian-stir-fried-mixed-vegetables.jpg',
                'caprese-salad-stack.jpg',
                'charred-corn-esquites.jpg',
                'roasted-beet-and-goat-cheese-salad.jpg',
                'eggplant-parmesan-bake.jpg',
            ],
        ];

        // Generic step templates applied to every recipe
        $stepTemplates = [
            ['title' => 'Prep Ingredients', 'instructions' => 'Gather and prepare all your ingredients. Wash, chop, and measure everything before you start cooking.', 'prep_time_minutes' => 10],
            ['title' => 'Cook / Assemble',  'instructions' => 'Follow the main cooking technique for this recipe — sauté, bake, blend, or assemble as needed.', 'prep_time_minutes' => 20],
            ['title' => 'Season & Taste',   'instructions' => 'Adjust seasoning to your preference. Add salt, pepper, herbs, or any finishing touches.', 'prep_time_minutes' => 5],
            ['title' => 'Plate & Serve',    'instructions' => 'Arrange the dish attractively on a plate. Garnish as desired and serve immediately while fresh.', 'prep_time_minutes' => 5],
        ];

        // Collect all downloaded step image paths (step1.jpg … stepN.jpg)
        $stepImagePaths = $this->collectStepImages();
        $stepImageCount = count($stepImagePaths);

        $globalIndex = 0;

        foreach ($categoriesData as $categoryName => $images) {
            $category = \App\Models\Category::firstOrCreate(['name' => $categoryName]);

            foreach ($images as $filename) {
                $title = ucwords(str_replace('-', ' ', pathinfo($filename, PATHINFO_FILENAME)));

                $recipe = Recipe::updateOrCreate(
                    [
                        'title'   => $title,
                        'user_id' => $user->id,
                    ],
                    [
                        'category_id'      => $category->id,
                        'prep_timing_mode' => 'per_step',
                        'instructions'     => implode("\n", array_map(
                            fn($i, $s) => ($i + 1).'. '.$s['instructions'],
                            array_keys($stepTemplates),
                            $stepTemplates
                        )),
                        'prep_time'        => array_sum(array_column($stepTemplates, 'prep_time_minutes')),
                    ]
                );

                // Attach recipe cover image
                $this->attachRecipeImage($recipe, $filename);

                // Seed structured steps (skip if already created)
                if ($recipe->steps()->exists()) {
                    $globalIndex++;
                    continue;
                }

                foreach ($stepTemplates as $sortOrder => $stepData) {
                    $step = RecipeStep::create([
                        'recipe_id'        => $recipe->id,
                        'sort_order'       => $sortOrder,
                        'title'            => $stepData['title'],
                        'instructions'     => $stepData['instructions'],
                        'prep_time_minutes'=> $stepData['prep_time_minutes'],
                    ]);

                    // Attach a step image (cycled through available images)
                    if ($stepImageCount > 0) {
                        $imgPath = $stepImagePaths[($globalIndex * count($stepTemplates) + $sortOrder) % $stepImageCount];
                        $this->attachStepImage($step, $imgPath);
                    }
                }

                $globalIndex++;
            }
        }

        // Backfill step images for any steps that were created without images
        $stepImages = $this->collectStepImages();
        if (count($stepImages) > 0) {
            $stepsWithoutImages = RecipeStep::whereDoesntHave('images')->get();
            foreach ($stepsWithoutImages as $idx => $step) {
                $imgPath = $stepImages[$idx % count($stepImages)];
                $this->attachStepImage($step, $imgPath);
            }
            $this->command->info('Attached images to '.count($stepsWithoutImages).' steps.');
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /** Returns list of absolute paths to downloaded step images. */
    private function collectStepImages(): array
    {
        $candidates = [
            dirname(base_path(), 2).'/storage/app/public/steps',
            storage_path('app/public/steps'),
        ];
        foreach ($candidates as $dir) {
            if (!is_dir($dir)) continue;
            $files = glob($dir.'/*.{jpg,jpeg,png,webp}', GLOB_BRACE) ?: [];
            if (count($files) > 0) {
                sort($files);
                return $files;
            }
        }
        return [];
    }

    /** Copy a recipe cover image from the recipes/ folder into seeded storage. */
    private function attachRecipeImage(Recipe $recipe, string $filename): void
    {
        if ($recipe->images()->exists()) return;

        $srcPaths = [
            dirname(base_path(), 2).'/storage/app/public/recipes/'.$filename,
            storage_path('app/public/recipes/'.$filename),
        ];

        $src = null;
        foreach ($srcPaths as $path) {
            if (file_exists($path)) { $src = $path; break; }
        }

        if (! $src) {
            $this->command->warn("Recipe image not found: {$filename}");
            return;
        }

        $bytes = @file_get_contents($src);
        if (! $bytes) return;

        $ext  = strtolower(pathinfo($src, PATHINFO_EXTENSION)) ?: 'jpg';
        $dest = 'recipes/seed/'.$recipe->id.'_'.Str::random(8).'.'.$ext;
        Storage::disk('public')->makeDirectory('recipes/seed');
        Storage::disk('public')->put($dest, $bytes);
        $recipe->images()->create(['path' => $dest]);
    }

    /** Copy a step image from the steps/ folder into seeded storage and link it. */
    private function attachStepImage(RecipeStep $step, string $srcPath): void
    {
        if ($step->images()->count() > 0) return;

        $bytes = @file_get_contents($srcPath);
        if (! $bytes) return;

        $ext  = strtolower(pathinfo($srcPath, PATHINFO_EXTENSION)) ?: 'jpg';
        $dest = 'steps/seed/'.$step->id.'_'.Str::random(8).'.'.$ext;
        Storage::disk('public')->makeDirectory('steps/seed');
        Storage::disk('public')->put($dest, $bytes);
        $step->images()->create(['path' => $dest, 'sort_order' => 0]);
    }
}
