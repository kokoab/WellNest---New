<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Post;
use App\Models\Recipe;
use App\Models\User;
use App\Support\JohnTestRealisticRecipes;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * Demo account for dashboards / QA:
 * john test · test5@gmail.com · password: 12345678
 *
 * Ensures at least JOHN_TEST_DEMO_RECIPES_MIN recipes (default 90) and
 * JOHN_TEST_DEMO_RECIPE_POSTS_MIN posts linked to recipes (default 50).
 * Optionally ensures at least JOHN_TEST_DEMO_POSTS_MIN plain posts (no recipe link).
 * Falls back to JOHN_TEST_DEMO_POSTS when POSTS_MIN unset (default 300).
 *
 * Env overrides:
 * - JOHN_TEST_REALISTIC_RECIPES_WITH_PHOTOS_MIN (default 30; 0 skips photo recipes — runs before bulk recipe fill)
 * - JOHN_TEST_DEMO_RECIPES_MIN (0 skips bulk recipes)
 * - JOHN_TEST_DEMO_RECIPE_POSTS_MIN (0 skips recipe-linked posts)
 * - JOHN_TEST_DEMO_POSTS_MIN or JOHN_TEST_DEMO_POSTS (0 skips plain posts)
 */
class JohnTestDemoUserSeeder extends Seeder
{
    public function run(): void
    {
        $email = 'test5@gmail.com';

        $user = User::updateOrCreate(
            ['email' => $email],
            [
                'first_name' => 'john',
                'last_name' => 'test',
                'password' => Hash::make('12345678'),
                'role' => 'user',
                'status' => 'active',
                'account_status' => 'active',
                'is_admin' => false,
            ]
        );

        $categories = Category::query()->get();
        if ($categories->isEmpty()) {
            Category::factory()->count(10)->create();
            $categories = Category::query()->get();
        }

        $realisticPhotoMin = (int) env('JOHN_TEST_REALISTIC_RECIPES_WITH_PHOTOS_MIN', 30);
        if ($realisticPhotoMin > 0) {
            $addedPhotoRecipes = JohnTestRealisticRecipes::seedPhotographedRecipes($user, $categories, $realisticPhotoMin);
            if ($this->command && $addedPhotoRecipes > 0) {
                $this->command->info("John test demo: added {$addedPhotoRecipes} realistic recipes with photos (minimum with images {$realisticPhotoMin}).");
            }
        }

        $recipesMin = (int) env('JOHN_TEST_DEMO_RECIPES_MIN', 90);
        if ($recipesMin > 0) {
            $have = Recipe::where('user_id', $user->id)->count();
            $need = max(0, $recipesMin - $have);
            // Avoid Recipe::factory() bulk here: its ingredient hook exhausts Faker unique words.
            for ($i = 0; $i < $need; $i++) {
                Recipe::query()->create([
                    'user_id' => $user->id,
                    'category_id' => $categories->random()->id,
                    'title' => ucwords(rtrim(fake()->sentence(fake()->numberBetween(2, 5)), '.')),
                    'description' => fake()->paragraph(),
                    'instructions' => fake()->paragraph(),
                    'prep_time' => fake()->numberBetween(5, 90),
                ]);
            }
            if ($this->command && $need > 0) {
                $this->command->info("John test demo: added {$need} recipes (target min {$recipesMin}, now ".Recipe::where('user_id', $user->id)->count().').');
            }
        }

        $recipePostsMin = (int) env('JOHN_TEST_DEMO_RECIPE_POSTS_MIN', 50);
        if ($recipePostsMin > 0) {
            $recipeIds = Recipe::where('user_id', $user->id)->pluck('id');
            $havePosts = Post::where('user_id', $user->id)->whereNotNull('recipe_id')->count();
            $needPosts = max(0, $recipePostsMin - $havePosts);
            for ($i = 0; $i < $needPosts; $i++) {
                Post::factory()->create([
                    'user_id' => $user->id,
                    'recipe_id' => $recipeIds->random(),
                    'image_url' => null,
                ]);
            }
            if ($this->command && $needPosts > 0) {
                $this->command->info("John test demo: added {$needPosts} recipe-linked posts (target min {$recipePostsMin}, now ".Post::where('user_id', $user->id)->whereNotNull('recipe_id')->count().').');
            }
        }

        $plainPostsMin = (int) env(
            'JOHN_TEST_DEMO_POSTS_MIN',
            (string) env('JOHN_TEST_DEMO_POSTS', '300')
        );
        if ($plainPostsMin > 0) {
            $plainHave = Post::where('user_id', $user->id)->whereNull('recipe_id')->count();
            $needPlain = max(0, $plainPostsMin - $plainHave);
            if ($needPlain > 0) {
                Post::factory()
                    ->count($needPlain)
                    ->create([
                        'user_id' => $user->id,
                        'recipe_id' => null,
                        'image_url' => null,
                    ]);
            }
            if ($this->command && $needPlain > 0) {
                $this->command->info("John test demo: added {$needPlain} plain posts (target min {$plainPostsMin}).");
            }
        }

        if ($this->command) {
            $totalPosts = Post::where('user_id', $user->id)->count();
            $recipePosts = Post::where('user_id', $user->id)->whereNotNull('recipe_id')->count();
            $recipeTotal = Recipe::where('user_id', $user->id)->count();
            $recipesWithImages = Recipe::where('user_id', $user->id)->whereHas('images')->count();
            $this->command->info("John test demo summary ({$email}): recipes={$recipeTotal} (with images: {$recipesWithImages}), posts total={$totalPosts}, posts with recipe={$recipePosts}.");
        }
    }
}
