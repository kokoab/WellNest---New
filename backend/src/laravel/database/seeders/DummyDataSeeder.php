<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Image;
use App\Models\Ingredient;
use App\Models\Post;
use App\Models\Recipe;
use App\Models\RecipeStep;
use App\Models\User;
use App\Models\Vote;
use Carbon\CarbonImmutable;
use Database\Seeders\Concerns\SeedsHistoryRange;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class DummyDataSeeder extends Seeder
{
    use SeedsHistoryRange;

    private const STEP_TEMPLATES = [
        ['title' => 'Prep Ingredients', 'instructions' => 'Gather, wash, chop, and measure everything before cooking.', 'prep_time_minutes' => 10],
        ['title' => 'Cook / Assemble', 'instructions' => 'Cook or assemble the main components of the recipe.', 'prep_time_minutes' => 20],
        ['title' => 'Season & Serve', 'instructions' => 'Adjust seasoning, plate the dish, and serve while fresh.', 'prep_time_minutes' => 5],
    ];

    private const DUMMY_USER_COUNT = 1000;

    private const RECIPE_TARGET_TOTAL = 10000;

    private const POST_COUNT = 8000;

    private const VOTE_COUNT = 4000;

    private const INSERT_CHUNK = 400;

    public function run(): void
    {
        $categories = Category::all();
        $imagePaths = $this->existingImagePaths();

        if ($categories->isEmpty()) {
            $this->command->warn('No categories found. Run CategorySeeder first.');

            return;
        }

        if ($imagePaths === []) {
            $this->command->warn('No existing images found. Dummy recipes and posts will have no gallery images.');
        }

        $users = User::query()
            ->where('email', 'like', '%@seed.wellnest')
            ->orderBy('id')
            ->limit(self::DUMMY_USER_COUNT)
            ->get();

        if ($users->count() < self::DUMMY_USER_COUNT) {
            $startIndex = $users->count();
            for ($u = $startIndex; $u < self::DUMMY_USER_COUNT; $u++) {
                $user = User::factory()->create([
                    'email' => sprintf('dummy_u_%d_%s@seed.wellnest', $u, Str::lower(Str::random(10))),
                ]);
                $users->push($user);
            }
            $users = $users->sortBy('id')->values();
        }

        $dummyUserIds = $users->pluck('id')->all();

        foreach ($users->values() as $index => $user) {
            $ts = $this->biasedUserSignupAt($index, self::DUMMY_USER_COUNT, $user->id);
            DB::table('users')->where('id', $user->id)->update([
                'created_at' => $ts->toDateTimeString(),
                'updated_at' => $ts->toDateTimeString(),
            ]);
        }

        $users = User::query()->whereIn('id', $dummyUserIds)->orderBy('id')->get();
        $usersById = $users->keyBy('id');

        $recipeCount = Recipe::query()->count();
        $neededRecipes = max(0, self::RECIPE_TARGET_TOTAL - $recipeCount);
        $dummyPostsSoFar = Post::query()->whereIn('user_id', $dummyUserIds)->count();
        $postsToCreate = max(0, self::POST_COUNT - $dummyPostsSoFar);
        $dummyVotesSoFar = Vote::query()->whereIn('user_id', $dummyUserIds)->count();
        $votesToCreate = max(0, self::VOTE_COUNT - $dummyVotesSoFar);

        if ($neededRecipes > 0) {
            $this->backfillCatalogRecipeImages($imagePaths);
            $this->command->info("Bulk-inserting {$neededRecipes} dummy recipes (current {$recipeCount}, target ".self::RECIPE_TARGET_TOTAL.').');
            $this->bulkInsertDummyRecipes($users, $usersById, $categories, $neededRecipes);
            $this->bulkInsertDummyRecipeSteps($dummyUserIds);
            $this->bulkAttachDummyPlaceholderIngredient($dummyUserIds);
        } else {
            $this->command->info(
                "Recipes: {$recipeCount} rows already meet the target (".self::RECIPE_TARGET_TOTAL.') — skipping dummy recipe inserts.'
            );
        }

        if ($postsToCreate > 0) {
            $this->backfillCatalogPostImages($imagePaths);
            $this->command->info("Bulk-inserting {$postsToCreate} dummy posts (have {$dummyPostsSoFar}).");
            $this->bulkInsertDummyPosts($users, $usersById, $dummyPostsSoFar, $postsToCreate);
        } else {
            $this->command->info(
                "Dummy-authored posts already at or above the target (".self::POST_COUNT.", have {$dummyPostsSoFar})."
            );
        }

        if ($votesToCreate > 0) {
            $postIds = Post::query()->pluck('id')->all();
            if ($postIds !== []) {
                $this->command->info("Bulk-inserting {$votesToCreate} dummy votes (have {$dummyVotesSoFar}).");
                $this->bulkInsertDummyVotes($users, $usersById, $postIds, $dummyVotesSoFar, $votesToCreate);
            }
        }
    }

    /**
     * @param  \Illuminate\Support\Collection<int, User>  $users
     * @param  \Illuminate\Support\Collection<int, User>  $usersById
     * @param  \Illuminate\Support\Collection<int, Category>  $categories
     */
    private function bulkInsertDummyRecipes($users, $usersById, $categories, int $neededRecipes): void
    {
        $categoryIds = $categories->pluck('id')->all();
        $nCats = count($categoryIds);
        $batch = [];

        for ($i = 0; $i < $neededRecipes; $i++) {
            $user = $users->random();
            $userCreated = CarbonImmutable::parse($usersById->get($user->id)->created_at)->utc();
            $ts = $this->contentCreatedAtUtc($userCreated, 'dummy-recipe', $i)->toDateTimeString();

            $batch[] = [
                'user_id' => $user->id,
                'category_id' => $categoryIds[$i % $nCats],
                'title' => 'Dummy recipe '.Str::lower((string) Str::ulid()),
                'description' => 'Seeded dummy recipe for development.',
                'instructions' => 'Seeded dummy instructions.',
                'prep_time' => 35,
                'prep_timing_mode' => 'per_step',
                'created_at' => $ts,
                'updated_at' => $ts,
            ];

            if (count($batch) >= self::INSERT_CHUNK) {
                DB::table('recipes')->insert($batch);
                $batch = [];
                if (($i + 1) % 2000 === 0) {
                    $this->command->info('Recipes inserted: '.($i + 1).' / '.$neededRecipes);
                }
            }
        }

        if ($batch !== []) {
            DB::table('recipes')->insert($batch);
        }
    }

    /**
     * @param  list<int>  $dummyUserIds
     */
    private function bulkInsertDummyRecipeSteps(array $dummyUserIds): void
    {
        $nowStr = now()->toDateTimeString();
        Recipe::query()
            ->whereIn('user_id', $dummyUserIds)
            ->whereDoesntHave('steps')
            ->orderBy('id')
            ->chunkById(120, function ($recipes) use ($nowStr) {
                $rows = [];
                foreach ($recipes as $recipe) {
                    foreach (self::STEP_TEMPLATES as $sort => $template) {
                        $rows[] = [
                            'recipe_id' => $recipe->id,
                            'sort_order' => $sort,
                            'title' => $template['title'],
                            'instructions' => $template['instructions'],
                            'prep_time_minutes' => $template['prep_time_minutes'],
                            'created_at' => $nowStr,
                            'updated_at' => $nowStr,
                        ];
                    }
                }
                if ($rows !== []) {
                    DB::table('recipe_steps')->insert($rows);
                }
            });

        $prepSum = (int) collect(self::STEP_TEMPLATES)->sum('prep_time_minutes');
        DB::table('recipes')
            ->whereIn('user_id', $dummyUserIds)
            ->update([
                'prep_timing_mode' => 'per_step',
                'prep_time' => $prepSum,
            ]);
    }

    /**
     * @param  list<int>  $dummyUserIds
     */
    private function bulkAttachDummyPlaceholderIngredient(array $dummyUserIds): void
    {
        $ingredient = Ingredient::query()->firstOrCreate(['name' => 'Dummy seed placeholder']);

        $nowStr = now()->toDateTimeString();

        Recipe::query()
            ->whereIn('user_id', $dummyUserIds)
            ->whereDoesntHave('ingredients')
            ->orderBy('id')
            ->chunkById(400, function ($recipes) use ($ingredient, $nowStr) {
                $rows = [];
                foreach ($recipes as $recipe) {
                    $rows[] = [
                        'recipe_id' => $recipe->id,
                        'ingredient_id' => $ingredient->id,
                        'quantity' => 1,
                        'unit' => 'pinch',
                        'created_at' => $nowStr,
                        'updated_at' => $nowStr,
                    ];
                }
                if ($rows !== []) {
                    DB::table('recipe_ingredients')->insert($rows);
                }
            });
    }

    /**
     * @param  \Illuminate\Support\Collection<int, User>  $users
     * @param  \Illuminate\Support\Collection<int, User>  $usersById
     */
    private function bulkInsertDummyPosts($users, $usersById, int $dummyPostsSoFar, int $postsToCreate): void
    {
        $batch = [];
        for ($i = 0; $i < $postsToCreate; $i++) {
            $user = $users->random();
            $userCreated = CarbonImmutable::parse($usersById->get($user->id)->created_at)->utc();
            $ts = $this->postPublishedAtUtc($userCreated, 'dummy-post', $dummyPostsSoFar + $i)->toDateTimeString();

            $batch[] = [
                'user_id' => $user->id,
                'recipe_id' => null,
                'title' => 'Dummy post '.Str::lower((string) Str::ulid()),
                'content' => 'Seeded dummy post body for development.',
                'image_url' => null,
                'created_at' => $ts,
                'updated_at' => $ts,
            ];

            if (count($batch) >= self::INSERT_CHUNK) {
                DB::table('posts')->insert($batch);
                $batch = [];
            }
        }

        if ($batch !== []) {
            DB::table('posts')->insert($batch);
        }
    }

    /**
     * @param  \Illuminate\Support\Collection<int, User>  $users
     * @param  \Illuminate\Support\Collection<int, User>  $usersById
     * @param  list<int>  $postIds
     */
    private function bulkInsertDummyVotes($users, $usersById, array $postIds, int $dummyVotesSoFar, int $votesToCreate): void
    {
        $postCount = count($postIds);
        $batch = [];

        for ($i = 0; $i < $votesToCreate; $i++) {
            $user = $users->random();
            $userCreated = CarbonImmutable::parse($usersById->get($user->id)->created_at)->utc();
            $ts = $this->contentCreatedAtUtc($userCreated, 'dummy-vote', $dummyVotesSoFar + $i)->toDateTimeString();

            $postId = $postIds[abs(crc32('dummy-vote-post|'.$i)) % $postCount];

            $batch[] = [
                'user_id' => $user->id,
                'votable_id' => $postId,
                'votable_type' => Post::class,
                'vote' => random_int(0, 1),
                'created_at' => $ts,
                'updated_at' => $ts,
            ];

            if (count($batch) >= self::INSERT_CHUNK) {
                DB::table('votes')->insert($batch);
                $batch = [];
            }
        }

        if ($batch !== []) {
            DB::table('votes')->insert($batch);
        }
    }

    /**
     * @param  list<string>  $imagePaths
     */
    private function backfillCatalogRecipeImages(array $imagePaths): void
    {
        if ($imagePaths === []) {
            return;
        }

        Recipe::query()
            ->whereDoesntHave('images')
            ->orderBy('id')
            ->chunkById(80, function ($recipes) use ($imagePaths) {
                foreach ($recipes as $recipe) {
                    $this->ensureRecipeMedia($recipe, $imagePaths, (int) $recipe->id);
                }
            });
    }

    /**
     * @param  list<string>  $imagePaths
     */
    private function backfillCatalogPostImages(array $imagePaths): void
    {
        if ($imagePaths === []) {
            return;
        }

        Post::query()
            ->whereDoesntHave('images')
            ->orderBy('id')
            ->chunkById(80, function ($posts) use ($imagePaths) {
                foreach ($posts as $post) {
                    $this->ensurePostMedia($post, $imagePaths, (int) $post->id);
                }
            });
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
