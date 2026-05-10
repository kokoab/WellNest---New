<?php

namespace Database\Seeders;

use App\Models\Recipe;
use App\Models\RecipeStep;
use Carbon\CarbonImmutable;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
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

        /** @var array<string, list<array{title: string, description: string, instructions: string, prep_time: int}>> $definitions */
        $definitions = require __DIR__.'/data/recipe_definitions.php';

        $categoriesByName = \App\Models\Category::query()
            ->whereIn('name', array_keys($definitions))
            ->get()
            ->keyBy('name');

        if ($categoriesByName->isEmpty()) {
            $this->command->warn('No categories found. Run CategorySeeder first.');

            return;
        }

        $templates = $this->imageTemplatePaths();
        $remoteUrls = $this->foodImageUrls();

        /** @var array<string, list<array{name: string, quantity: int, unit: string}>> $ingredientPools */
        $ingredientPools = require __DIR__.'/data/recipe_ingredient_pools.php';

        // Generic per-step blueprint applied to every recipe so that the
        // structured-step UI (with per-step images) has something to render.
        // The free-form `instructions` text on the Recipe row still comes from
        // recipe_definitions.php and stays the source of truth for prose.
        $stepTemplates = [
            ['title' => 'Prep Ingredients', 'instructions' => 'Gather and prepare all your ingredients. Wash, chop, and measure everything before you start cooking.', 'prep_time_minutes' => 10],
            ['title' => 'Cook / Assemble',  'instructions' => 'Follow the main cooking technique for this recipe — sauté, bake, blend, or assemble as needed.', 'prep_time_minutes' => 20],
            ['title' => 'Season & Taste',   'instructions' => 'Adjust seasoning to your preference. Add salt, pepper, herbs, or any finishing touches.', 'prep_time_minutes' => 5],
            ['title' => 'Plate & Serve',    'instructions' => 'Arrange the dish attractively on a plate. Garnish as desired and serve immediately while fresh.', 'prep_time_minutes' => 5],
        ];

        $stepImagePaths = $this->collectStepImages();
        $stepImageCount = count($stepImagePaths);

        $index = 0;

        foreach ($definitions as $categoryName => $rows) {
            $category = $categoriesByName->get($categoryName);
            if (! $category) {
                $this->command->warn("Skipping recipes for missing category: {$categoryName}");

                continue;
            }

            foreach ($rows as $row) {
                $data = [
                    'user_id' => $user->id,
                    'category_id' => $category->id,
                    'title' => $row['title'],
                    'description' => $row['description'],
                    'instructions' => $row['instructions'],
                    'prep_time' => $row['prep_time'],
                    'prep_timing_mode' => 'per_step',
                ];

                $recipe = Recipe::updateOrCreate(
                    [
                        'title' => $data['title'],
                        'user_id' => $user->id,
                    ],
                    $data
                );

                $this->stampRecipeCreatedAt($recipe);
                $this->syncRecipeIngredients($recipe, $categoryName, $row['title'], $ingredientPools);
                $this->ensureRecipeSeedImages($recipe, $templates, $remoteUrls, $index, $categoryName);
                $this->seedRecipeSteps($recipe, $categoryName, $stepTemplates, $stepImagePaths, $stepImageCount, $index);

                $index++;
            }
        }

        foreach (Recipe::query()->whereDoesntHave('images')->with('category')->cursor() as $recipe) {
            $categoryName = $recipe->category?->name ?? '';
            $this->ensureRecipeSeedImages($recipe, $templates, $remoteUrls, (int) $recipe->id, $categoryName);
        }

        foreach (Recipe::query()->whereDoesntHave('ingredients')->with('category')->cursor() as $recipe) {
            $categoryName = $recipe->category?->name ?? '_default';
            $this->syncRecipeIngredients($recipe, $categoryName, $recipe->title, $ingredientPools);
        }

        foreach (Recipe::query()->cursor() as $recipe) {
            $this->stampRecipeCreatedAt($recipe);
        }

        // Backfill step images for any RecipeStep rows missing one. Prefers the
        // global step pool if available, otherwise reuses the recipe's own cover
        // image so each step still has a meaningful photo.
        $stepsWithoutImages = RecipeStep::with('recipe.category')->whereDoesntHave('images')->get();
        $backfilled = 0;
        foreach ($stepsWithoutImages as $idx => $step) {
            $imgPath = null;
            if ($stepImageCount > 0) {
                $imgPath = $stepImagePaths[$idx % $stepImageCount];
            } elseif ($step->recipe !== null) {
                $imgPath = $this->resolveRecipeFallbackImagePath(
                    $step->recipe->title,
                    $step->recipe->category?->name ?? ''
                );
            }
            if ($imgPath !== null && $this->attachStepImage($step, $imgPath)) {
                $backfilled++;
            }
        }
        if ($backfilled > 0) {
            $this->command->info("Attached images to {$backfilled} steps.");
        }
    }

    /**
     * Create the four generic RecipeStep rows for a recipe (idempotent) and
     * attach a step image to each. Prefers the global step image pool (cycled
     * deterministically by the recipe's global index for stable re-seeds);
     * otherwise falls back to the recipe's own cover image so every step
     * still gets a meaningful photo.
     *
     * @param  list<array{title: string, instructions: string, prep_time_minutes: int}>  $stepTemplates
     * @param  list<string>  $stepImagePaths
     */
    private function seedRecipeSteps(Recipe $recipe, string $categoryName, array $stepTemplates, array $stepImagePaths, int $stepImageCount, int $globalIndex): void
    {
        if ($recipe->steps()->exists()) {
            return;
        }

        $stepCount = count($stepTemplates);
        $recipeFallback = $stepImageCount === 0
            ? $this->resolveRecipeFallbackImagePath($recipe->title, $categoryName)
            : null;

        foreach ($stepTemplates as $sortOrder => $stepData) {
            $step = RecipeStep::create([
                'recipe_id' => $recipe->id,
                'sort_order' => $sortOrder,
                'title' => $stepData['title'],
                'instructions' => $stepData['instructions'],
                'prep_time_minutes' => $stepData['prep_time_minutes'],
            ]);

            $imgPath = null;
            if ($stepImageCount > 0) {
                $imgPath = $stepImagePaths[($globalIndex * $stepCount + $sortOrder) % $stepImageCount];
            } elseif ($recipeFallback !== null) {
                $imgPath = $recipeFallback;
            }
            if ($imgPath !== null) {
                $this->attachStepImage($step, $imgPath);
            }
        }
    }

    /**
     * Best-effort: returns the same image path the recipe gallery seeder would
     * use as the cover (per-recipe override -> bundled lane image). Used to
     * give every step a meaningful photo when no dedicated step image pool is
     * available under storage/app/public/steps.
     */
    private function resolveRecipeFallbackImagePath(string $title, string $categoryName): ?string
    {
        $override = $this->perRecipeOverridePath($title);
        if ($override !== null) {
            return $override;
        }

        $basenames = $this->recipeSeedImageBasenames($title, $categoryName);
        foreach ($basenames as $basename) {
            $path = $this->bundledRecipeImagePath($basename);
            if ($path !== null) {
                return $path;
            }
        }

        return null;
    }

    /**
     * Force created_at/updated_at to a deterministic random moment between
     * Jan 1 2025 00:00 UTC and "now". Same recipe title -> same timestamp on
     * re-seeds, so dates stay stable across runs (matches how ingredients and
     * image lanes are picked via crc32).
     */
    private function stampRecipeCreatedAt(Recipe $recipe): void
    {
        $ts = $this->recipeSeedTimestamp($recipe->title);

        DB::table('recipes')->where('id', $recipe->id)->update([
            'created_at' => $ts->toDateTimeString(),
            'updated_at' => $ts->toDateTimeString(),
        ]);
    }

    private function recipeSeedTimestamp(string $title): CarbonImmutable
    {
        $start = CarbonImmutable::create(2025, 1, 1, 0, 0, 0, 'UTC');
        $end = CarbonImmutable::now('UTC');
        $rangeSeconds = max(1, $end->getTimestamp() - $start->getTimestamp());
        $offset = (int) (abs(crc32('recipe-date|'.$title)) % $rangeSeconds);

        return $start->addSeconds($offset);
    }

    /**
     * @param  array<string, list<array{name: string, quantity: int, unit: string}>>  $pools
     */
    private function syncRecipeIngredients(Recipe $recipe, string $categoryName, string $title, array $pools): void
    {
        $pool = $pools[$categoryName] ?? $pools['_default'] ?? [];
        $lines = $this->pickIngredientLines($pool, $title, 6);

        $recipe->ingredients()->detach();
        foreach ($lines as $line) {
            $name = trim($line['name']);
            if ($name === '') {
                continue;
            }
            $ingredient = \App\Models\Ingredient::firstOrCreate(['name' => $name]);
            $qty = max(1, (int) $line['quantity']);
            $unit = trim($line['unit']) !== '' ? trim($line['unit']) : 'unit';
            $recipe->ingredients()->attach($ingredient->id, [
                'quantity' => $qty,
                'unit' => $unit,
            ]);
        }
    }

    /**
     * @param  list<array{name: string, quantity: int, unit: string}>  $pool
     * @return list<array{name: string, quantity: int, unit: string}>
     */
    private function pickIngredientLines(array $pool, string $title, int $count): array
    {
        $n = count($pool);
        if ($n === 0) {
            return [];
        }

        $want = min($count, $n);
        $crc = crc32($title);
        $start = $n > 0 ? (($crc % $n) + $n) % $n : 0;
        $seen = [];
        $out = [];

        for ($i = 0; $i < $n && count($out) < $want; $i++) {
            $row = $pool[($start + $i) % $n];
            $name = $row['name'];
            if (isset($seen[$name])) {
                continue;
            }
            $seen[$name] = true;
            $out[] = $row;
        }

        return $out;
    }

    /**
     * Fallback food-photo URLs when bundled seed images are missing (HTTPS).
     *
     * @return list<string>
     */
    private function foodImageUrls(): array
    {
        return [
            'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1499028344343-cd173ffc68a9?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1484723091739-30a097e8f929?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1551218808-94e220e084d2?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1493770348161-369560ae357d?auto=format&fit=crop&w=1200&q=80',
            'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?auto=format&fit=crop&w=1200&q=80',
        ];
    }

    /**
     * @return list<string> absolute paths to existing recipe images (bundled seed assets, then storage).
     */
    private function imageTemplatePaths(): array
    {
        $bundledDir = __DIR__.DIRECTORY_SEPARATOR.'assets'.DIRECTORY_SEPARATOR.'recipe_images';
        $paths = $this->globImageFilesInDir($bundledDir);
        if ($paths !== []) {
            sort($paths);

            return $paths;
        }

        $dirs = [
            dirname(base_path(), 2).DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.'recipes',
            storage_path('app/public/recipes'),
        ];
        foreach ($dirs as $dir) {
            $found = $this->globImageFilesInDir($dir);
            foreach ($found as $path) {
                if (str_contains($path, 'recipes'.DIRECTORY_SEPARATOR.'seed'.DIRECTORY_SEPARATOR)) {
                    continue;
                }
                $paths[] = $path;
            }
            if ($paths !== []) {
                return array_values(array_unique($paths));
            }
        }

        return [];
    }

    /**
     * Returns absolute paths of available step images. Looks first under
     * storage/app/public/steps (preferred) then falls back to bundled seeders
     * assets if a steps folder is added there later.
     *
     * @return list<string>
     */
    private function collectStepImages(): array
    {
        $candidates = [
            dirname(base_path(), 2).DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.'steps',
            storage_path('app/public/steps'),
            __DIR__.DIRECTORY_SEPARATOR.'assets'.DIRECTORY_SEPARATOR.'step_images',
        ];

        foreach ($candidates as $dir) {
            $files = $this->globImageFilesInDir($dir);
            if ($files !== []) {
                sort($files);

                return $files;
            }
        }

        return [];
    }

    /**
     * Collect image paths portably (GLOB_BRACE is unavailable on Windows PHP glob()).
     *
     * @return list<string>
     */
    private function globImageFilesInDir(string $dir): array
    {
        if (! is_dir($dir)) {
            return [];
        }
        $paths = [];
        foreach (['jpg', 'jpeg', 'png', 'webp'] as $ext) {
            $glob = glob($dir.DIRECTORY_SEPARATOR.'*.'.strtolower($ext));
            if ($glob !== false) {
                foreach ($glob as $path) {
                    $paths[] = $path;
                }
            }
        }

        return array_values(array_unique($paths));
    }

    /**
     * Attach up to three gallery images per recipe (bundled assets, then remote URLs).
     *
     * Bundled filenames are chosen from title + category so each recipe maps to a stable
     * lane in {@see recipeSeedImageBasenames}; falls back to rotating all templates by index.
     *
     * @param  list<string>  $templates
     * @param  list<string>  $remoteUrls
     */
    private function ensureRecipeSeedImages(Recipe $recipe, array $templates, array $remoteUrls, int $index, string $categoryName = ''): void
    {
        if ($recipe->images()->exists()) {
            return;
        }

        $maxGallery = 3;
        $added = 0;
        $preferredBasenames = $this->recipeSeedImageBasenames($recipe->title, $categoryName);
        $overridePath = $this->perRecipeOverridePath($recipe->title);

        for ($slot = 0; $slot < $maxGallery; $slot++) {
            $bytes = null;
            $hint = '';

            if ($slot === 0 && $overridePath !== null) {
                $read = @file_get_contents($overridePath);
                if ($read !== false && $read !== '') {
                    $bytes = $read;
                    $hint = $overridePath;
                }
            }

            if ($bytes === null && $templates !== []) {
                $basename = $preferredBasenames[$slot] ?? '';
                $src = $basename !== ''
                    ? $this->bundledRecipeImagePath($basename)
                    : null;
                if ($src !== null) {
                    $read = @file_get_contents($src);
                    if ($read !== false && $read !== '') {
                        $bytes = $read;
                        $hint = $src;
                    }
                }
                if ($bytes === null) {
                    $src = $templates[($index + $slot) % count($templates)];
                    $read = @file_get_contents($src);
                    if ($read !== false && $read !== '') {
                        $bytes = $read;
                        $hint = $src;
                    }
                }
            }

            if ($bytes === null && $remoteUrls !== []) {
                for ($try = 0; $try < 3; $try++) {
                    $url = $remoteUrls[($index + $slot + $try) % count($remoteUrls)];
                    $downloaded = $this->downloadRemoteImage($url);
                    if ($downloaded !== null && $downloaded !== '') {
                        $bytes = $downloaded;
                        $hint = $url;
                        break;
                    }
                }
            }

            if ($bytes === null || $bytes === '') {
                break;
            }

            $this->storeRecipeImageBytes($recipe, $bytes, $hint, $added);
            $added++;
        }

        if ($added === 0) {
            $this->command->warn('No recipe images available (add database/seeders/assets/recipe_images or check network); skipped images for recipe ID '.$recipe->id.'.');
        }
    }

    /**
     * Three bundled filenames for gallery slots (food_01.jpg … food_20.jpg), derived from recipe semantics.
     *
     * @return list<string>
     */
    private function recipeSeedImageBasenames(string $title, string $categoryName): array
    {
        $pick = static function (int $n): string {
            $n = (($n - 1) % 20) + 1;

            return sprintf('food_%02d.jpg', $n);
        };

        $t = strtolower($title);
        $base = null;

        if ($categoryName === 'Pet-Safe') {
            $lane = 19;
            $jitter = (crc32($title) % 5) - 2;
            $base = max(1, min(20, $lane + $jitter));
        } else {
            $overrides = [
                ['/chocolate|brownie|tiramisu|crème brûlée|crème brulee|soufflé|souffle|cheesecake|churro|cobbler|shortcake|pudding|crisp with oats|panna|brûlée/i', 17],
                ['/smoothie|latte|lassi|limeade|iced tea|iced brown|aguas|mocktail|cider|hot chocolate|wellness shot|posset/i', 18],
                ['/salmon|tuna|scallop|shrimp|clam|oyster|cod|lobster|branzino|vongole|poke bowl|chowder|sea bass|linguine|fish taco|miso.*cod/i', 11],
                ['/chicken|turkey|duck|cornish|coq au vin|chicken parmesan|buffalo chicken|chicken tikka|turkey chili|smoked paprika turkey/i', 13],
                ['/beef|steak|ribeye|pork tenderloin|lamb|burger|meatball|sausage|kofta|cheesesteak|pulled pork|banh mi/i', 15],
                ['/soup|chowder|minestrone|bisque|dal\b|chili\b|stew\b|cassoulet|pasta e fagioli|black bean soup/i', 5],
                ['/curry|tikka masala|risotto|paella|fried rice|stir-fry|ramen|pho|jackfruit slider/i', 7],
                ['/taco|enchilada|burrito|esquites|corn tortilla|tempura/i', 10],
                ['/toast|overnight oat|porridge|granola|breakfast sandwich|soft-boiled/i', 1],
                ['/salad|bowl\b|tabbouleh|caprese|slaw|skewers/i', 2],
            ];

            foreach ($overrides as [$pattern, $num]) {
                if (preg_match($pattern, $t)) {
                    $base = $num;

                    break;
                }
            }

            $categoryLane = [
                'Fruits' => 6,
                'Vegetables' => 4,
                'Grains' => 8,
                'Protein Foods' => 15,
                'Dairy Products' => 9,
                'Seafood' => 11,
                'Poultry' => 13,
                'Legumes' => 5,
                'Nuts and Seeds' => 12,
                'Fast Food' => 14,
                'Desserts' => 17,
                'Beverages' => 18,
                'Snacks' => 19,
                'Spices and Condiments' => 4,
                'Processed Foods' => 14,
                'Vegan' => 3,
                'Gluten-Free' => 4,
            ];

            if ($base === null && isset($categoryLane[$categoryName])) {
                $lane = $categoryLane[$categoryName];
                $jitter = (crc32($title) % 5) - 2;
                $base = max(1, min(20, $lane + $jitter));
            }

            if ($base === null) {
                $base = (abs(crc32($title.'|'.$categoryName)) % 20) + 1;
            }
        }

        return [$pick((int) $base), $pick((int) $base + 1), $pick((int) $base + 2)];
    }

    private function bundledRecipeImagePath(string $basename): ?string
    {
        $dir = __DIR__.DIRECTORY_SEPARATOR.'assets'.DIRECTORY_SEPARATOR.'recipe_images';
        $path = $dir.DIRECTORY_SEPARATOR.$basename;

        return is_file($path) ? $path : null;
    }

    /**
     * Look for a per-recipe cover override at assets/recipe_images/per_recipe/<slug>.{jpg,jpeg,png,webp}.
     *
     * The slug is derived from the recipe title via Str::slug, so dropping
     * `mango-lassi.jpg` overrides the cover for the "Mango Lassi" recipe.
     * Returns the absolute path of the first matching file, or null if none.
     */
    private function perRecipeOverridePath(string $title): ?string
    {
        $slug = Str::slug($title);
        if ($slug === '') {
            return null;
        }

        $dir = __DIR__.DIRECTORY_SEPARATOR.'assets'.DIRECTORY_SEPARATOR
            .'recipe_images'.DIRECTORY_SEPARATOR.'per_recipe';

        foreach (['jpg', 'jpeg', 'png', 'webp'] as $ext) {
            $path = $dir.DIRECTORY_SEPARATOR.$slug.'.'.$ext;
            if (is_file($path)) {
                return $path;
            }
        }

        return null;
    }

    private function downloadRemoteImage(string $url): ?string
    {
        try {
            $response = Http::timeout(20)
                ->withHeaders([
                    'User-Agent' => 'WellNestRecipeSeeder/1.0',
                    'Accept' => 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
                ])
                ->get($url);

            if ($response->successful()) {
                $body = $response->body();
                if ($body !== '') {
                    return $body;
                }
            }
        } catch (\Throwable) {
            // fall through
        }

        return null;
    }

    /**
     * @param  string  $sourceHint  URL or filesystem path (used for extension guess).
     */
    private function storeRecipeImageBytes(Recipe $recipe, string $bytes, string $sourceHint, int $sortOrder = 0): void
    {
        $ext = $this->guessImageExtension($sourceHint);
        $dest = 'recipes/seed/'.$recipe->id.'_'.Str::random(8).'.'.$ext;
        Storage::disk('public')->makeDirectory('recipes/seed');
        Storage::disk('public')->put($dest, $bytes);
        $recipe->images()->create([
            'path' => $dest,
            'sort_order' => $sortOrder,
        ]);
    }

    /**
     * Copy a step image from $srcPath into seeded storage and link it to the step.
     * Returns true if an image was actually attached, false otherwise.
     */
    private function attachStepImage(RecipeStep $step, string $srcPath): bool
    {
        if ($step->images()->exists()) {
            return false;
        }

        $bytes = @file_get_contents($srcPath);
        if ($bytes === false || $bytes === '') {
            return false;
        }

        $ext = $this->guessImageExtension($srcPath);
        $dest = 'steps/seed/'.$step->id.'_'.Str::random(8).'.'.$ext;
        Storage::disk('public')->makeDirectory('steps/seed');
        Storage::disk('public')->put($dest, $bytes);
        $step->images()->create([
            'path' => $dest,
            'sort_order' => 0,
        ]);

        return true;
    }

    private function guessImageExtension(string $sourceHint): string
    {
        $path = parse_url($sourceHint, PHP_URL_PATH);
        $base = is_string($path) ? $path : $sourceHint;
        $ext = strtolower(pathinfo($base, PATHINFO_EXTENSION));
        if (in_array($ext, ['jpg', 'jpeg', 'png', 'webp'], true)) {
            return $ext === 'jpeg' ? 'jpg' : $ext;
        }

        return 'jpg';
    }
}
