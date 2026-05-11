<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Image;
use App\Models\Post;
use App\Models\Recipe;
use App\Models\RecipeStep;
use App\Models\User;
use App\Models\Vote;
use Illuminate\Database\Seeder;


class DummyDataSeeder extends Seeder
{
    private const STEP_TEMPLATES = [
        ['title' => 'Prep Ingredients', 'instructions' => 'Gather, wash, chop, and measure everything before cooking.', 'prep_time_minutes' => 10],
        ['title' => 'Cook / Assemble', 'instructions' => 'Cook or assemble the main components of the recipe.', 'prep_time_minutes' => 20],
        ['title' => 'Season & Serve', 'instructions' => 'Adjust seasoning, plate the dish, and serve while fresh.', 'prep_time_minutes' => 5],
    ];

    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $users = User::factory()->count(200)->create();
        $categories = Category::all();
        $imagePaths = $this->existingImagePaths();

        if ($categories->isEmpty()) {
            $this->command->warn('No categories found. Run CategorySeeder first.');

            return;
        }

        if ($imagePaths === []) {
            $this->command->warn('No existing images found. Recipes, steps, and posts will be created without reused pictures.');
        }

        $this->backfillRecipeMedia($imagePaths);
        $this->backfillPostMedia($imagePaths);

        for ($i = 0; $i < 1000; $i++) {
            $user = $users->random();

            $choice = rand(1,3);

            match ($choice) {
                1 => tap(Post::factory()->create([
                    'user_id' => $user->id,
                    'image_url' => null,
                ]), fn (Post $post) => $this->ensurePostMedia($post, $imagePaths, $i)),
                2 => tap(Recipe::factory()->create([
                    'user_id' => $user->id,
                    'category_id' => $categories->random()->id,
                    'prep_timing_mode' => 'per_step',
                ]), fn (Recipe $recipe) => $this->ensureRecipeMedia($recipe, $imagePaths, $i)),
                3 => Vote::factory()->create(['user_id' => $user->id]),
            };
        }
    }

    /**
     * @return list<string>
     */
    private function existingImagePaths(): array
    {
        return Image::query()
            ->pluck('path')
            ->filter(fn ($path) => is_string($path) && trim($path) !== '')
            ->unique()
            ->values()
            ->all();
    }

    /**
     * Give already-seeded recipes the same media guarantees as newly-created dummy recipes.
     *
     * @param  list<string>  $imagePaths
     */
    private function backfillRecipeMedia(array $imagePaths): void
    {
        foreach (Recipe::query()->cursor() as $index => $recipe) {
            $this->ensureRecipeMedia($recipe, $imagePaths, $index);
        }
    }

    /**
     * Give already-seeded posts reusable feed images too.
     *
     * @param  list<string>  $imagePaths
     */
    private function backfillPostMedia(array $imagePaths): void
    {
        foreach (Post::query()->cursor() as $index => $post) {
            $this->ensurePostMedia($post, $imagePaths, $index);
        }
    }

    /**
     * @param  list<string>  $imagePaths
     */
    private function ensureRecipeMedia(Recipe $recipe, array $imagePaths, int $seed): void
    {
        if ($imagePaths !== [] && ! $recipe->images()->exists()) {
            $this->attachReusableImage($recipe, $imagePaths[$seed % count($imagePaths)]);
        }

        $steps = $recipe->steps()->get();
        foreach ($steps as $index => $step) {
            if ($imagePaths !== [] && ! $step->images()->exists()) {
                $this->attachReusableImage($step, $imagePaths[($seed + $index + 1) % count($imagePaths)]);
            }
        }

        $createdSteps = false;
        for ($index = $steps->count(); $index < count(self::STEP_TEMPLATES); $index++) {
            $template = self::STEP_TEMPLATES[$index];
            $step = RecipeStep::create([
                'recipe_id' => $recipe->id,
                'sort_order' => $index,
                'title' => $template['title'],
                'instructions' => $template['instructions'],
                'prep_time_minutes' => $template['prep_time_minutes'],
            ]);

            if ($imagePaths !== []) {
                $this->attachReusableImage($step, $imagePaths[($seed + $index + 1) % count($imagePaths)]);
            }

            $createdSteps = true;
        }

        if ($createdSteps) {
            $recipe->forceFill([
                'prep_timing_mode' => 'per_step',
                'prep_time' => $recipe->steps()->sum('prep_time_minutes'),
            ])->save();
        }
    }

    /**
     * @param  list<string>  $imagePaths
     */
    private function ensurePostMedia(Post $post, array $imagePaths, int $seed): void
    {
        if ($imagePaths !== [] && ! $post->images()->exists()) {
            $this->attachReusableImage($post, $imagePaths[$seed % count($imagePaths)]);
        }

        $cover = $post->images()->orderBy('sort_order')->orderBy('id')->first();
        if ($cover !== null) {
            $post->forceFill([
                'image_url' => rtrim(config('app.url'), '/').'/storage/'.$cover->path,
            ])->save();
        }
    }

    private function attachReusableImage($imageable, string $path, int $sortOrder = 0): void
    {
        $imageable->images()->create([
            'path' => $path,
            'sort_order' => $sortOrder,
        ]);
    }
}
