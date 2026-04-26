<?php

namespace Database\Seeders;

use App\Models\Recipe;
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

        $vegan = \App\Models\Category::where('name', 'Vegan')->first();
        $glutenFree = \App\Models\Category::where('name', 'Gluten-Free')->first();
        $petSafe = \App\Models\Category::where('name', 'Pet-Safe')->first();

        if (! $vegan) {
            $this->command->warn('No categories found. Run CategorySeeder first.');

            return;
        }

        $gfId = $glutenFree?->id ?? $vegan->id;
        $petId = $petSafe?->id ?? $vegan->id;

        $templates = $this->imageTemplatePaths();
        $i = 0;

        foreach ($this->recipes($user->id, $vegan->id, $gfId, $petId) as $data) {
            $recipe = Recipe::updateOrCreate(
                [
                    'title' => $data['title'],
                    'user_id' => $user->id,
                ],
                $data
            );
            $this->ensureRecipeCoverImage($recipe, $templates, $i);
            $i++;
        }

        foreach (Recipe::query()->whereDoesntHave('images')->cursor() as $recipe) {
            $this->ensureRecipeCoverImage($recipe, $templates, (int) $recipe->id);
        }
    }

    /**
     * @return list<string> absolute paths to existing recipe images (repo or local storage).
     */
    private function imageTemplatePaths(): array
    {
        $paths = [];
        $dirs = [
            dirname(base_path(), 2).DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.'recipes',
            storage_path('app/public/recipes'),
        ];
        foreach ($dirs as $dir) {
            if (! is_dir($dir)) {
                continue;
            }
            foreach (glob($dir.DIRECTORY_SEPARATOR.'*.{jpg,jpeg,png,webp}', GLOB_BRACE) ?: [] as $path) {
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
     * @param  list<string>  $templates
     */
    private function ensureRecipeCoverImage(Recipe $recipe, array $templates, int $index): void
    {
        if ($recipe->images()->exists()) {
            return;
        }
        if ($templates === []) {
            $this->command->warn('No recipe images found under storage/app/public/recipes; skipped covers.');

            return;
        }

        $src = $templates[$index % count($templates)];
        $bytes = @file_get_contents($src);
        if ($bytes === false || $bytes === '') {
            return;
        }

        $ext = strtolower(pathinfo($src, PATHINFO_EXTENSION)) ?: 'jpg';
        $dest = 'recipes/seed/'.$recipe->id.'_'.Str::random(8).'.'.$ext;
        Storage::disk('public')->makeDirectory('recipes/seed');
        Storage::disk('public')->put($dest, $bytes);
        $recipe->images()->create(['path' => $dest]);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function recipes(int $userId, int $veganId, int $glutenFreeId, int $petSafeId): array
    {
        return [
            [
                'user_id' => $userId,
                'category_id' => $veganId,
                'title' => 'Simple Avocado Toast',
                'description' => 'Creamy avocado on crisp toast with lemon and chili flakes—perfect for a quick breakfast or snack.',
                'instructions' => "1. Toast bread until golden and crisp.\n2. Halve the avocado, remove pit, and scoop flesh into a bowl.\n3. Mash with a fork; season with salt, pepper, and a squeeze of lemon.\n4. Spread evenly on toast.\n5. Top with chili flakes or microgreens if you like. Serve immediately.",
                'prep_time' => 8,
            ],
            [
                'user_id' => $userId,
                'category_id' => $veganId,
                'title' => 'Overnight Oats',
                'description' => 'No-cook oats soaked in plant milk with chia—ready when you wake up, topped with fresh fruit.',
                'instructions' => "1. In a jar, combine rolled oats, plant milk, chia seeds, and a pinch of salt.\n2. Sweeten lightly with maple syrup or mashed banana if desired.\n3. Stir well, seal, and refrigerate at least 6 hours (overnight is ideal).\n4. In the morning, stir; add splashes of milk to loosen if thick.\n5. Top with berries, nuts, or nut butter and enjoy cold.",
                'prep_time' => 10,
            ],
            [
                'user_id' => $userId,
                'category_id' => $glutenFreeId,
                'title' => 'Roasted Vegetables',
                'description' => 'Sheet-pan medley of seasonal vegetables with olive oil and herbs—naturally gluten-free and meal-prep friendly.',
                'instructions' => "1. Preheat oven to 200°C (400°F). Line a large baking sheet with parchment.\n2. Chop vegetables into similar-sized pieces for even cooking.\n3. Toss with olive oil, salt, pepper, and dried herbs (thyme or rosemary work well).\n4. Spread in a single layer without overcrowding.\n5. Roast 25–35 minutes, turning once, until tender and caramelized at the edges.",
                'prep_time' => 35,
            ],
            [
                'user_id' => $userId,
                'category_id' => $veganId,
                'title' => 'Mediterranean Chickpea Bowl',
                'description' => 'Protein-rich chickpeas with cucumber, tomato, olives, and a bright lemon-tahini dressing.',
                'instructions' => "1. Rinse and drain canned chickpeas; pat dry lightly.\n2. Whisk tahini, lemon juice, garlic, salt, and water until pourable.\n3. Dice cucumber and tomato; slice olives.\n4. Warm chickpeas in a pan with a little olive oil and smoked paprika (optional).\n5. Layer grains or greens, vegetables, and chickpeas; drizzle dressing. Finish with fresh herbs.",
                'prep_time' => 25,
            ],
            [
                'user_id' => $userId,
                'category_id' => $veganId,
                'title' => 'Ginger-Turmeric Lentil Soup',
                'description' => 'Comforting red lentil soup with warming ginger and turmeric—great for batch cooking.',
                'instructions' => "1. Sauté diced onion in oil until soft; add minced ginger and garlic for 1 minute.\n2. Stir in turmeric and cumin; cook 30 seconds until fragrant.\n3. Add rinsed red lentils, vegetable broth, and diced carrots.\n4. Simmer 20–25 minutes until lentils break down; stir occasionally.\n5. Season with salt and lemon. Blend partially for creaminess if you like, then serve.",
                'prep_time' => 45,
            ],
            [
                'user_id' => $userId,
                'category_id' => $glutenFreeId,
                'title' => 'Baked Lemon Herb Salmon',
                'description' => 'Flaky salmon fillets with lemon, garlic, and parsley—naturally gluten-free and oven-ready in minutes.',
                'instructions' => "1. Pat salmon fillets dry; place skin-side down on an oiled baking dish.\n2. Mix minced garlic, lemon zest, olive oil, salt, and pepper; brush over fish.\n3. Add thin lemon slices on top.\n4. Bake at 190°C (375°F) until fish flakes easily, about 12–15 minutes depending on thickness.\n5. Garnish with chopped parsley; serve with asparagus or salad.",
                'prep_time' => 22,
            ],
            [
                'user_id' => $userId,
                'category_id' => $veganId,
                'title' => 'Quinoa-Stuffed Bell Peppers',
                'description' => 'Colorful peppers filled with quinoa, black beans, corn, and spices—baked until tender.',
                'instructions' => "1. Halve peppers lengthwise; remove seeds and membranes.\n2. Cook quinoa according to package; fluff and cool slightly.\n3. Mix quinoa with black beans, corn, diced tomato, cumin, and smoked paprika.\n4. Stuff peppers; add a splash of water to the baking dish and cover with foil.\n5. Bake at 180°C (350°F) 35–40 minutes; uncover last 10 minutes. Top with cilantro.",
                'prep_time' => 50,
            ],
            [
                'user_id' => $userId,
                'category_id' => $veganId,
                'title' => 'Berry Spinach Smoothie Bowl',
                'description' => 'Thick, spoonable smoothie bowl packed with spinach, frozen berries, and banana—topped with crunch.',
                'instructions' => "1. Blend frozen berries, banana, a handful of spinach, and a little plant milk until thick (use minimal liquid).\n2. Pour into a bowl; surface should hold toppings without sinking.\n3. Arrange granola, sliced fruit, coconut flakes, and seeds on top.\n4. Drizzle nut butter if desired.\n5. Serve immediately while cold and thick.",
                'prep_time' => 12,
            ],
            [
                'user_id' => $userId,
                'category_id' => $veganId,
                'title' => 'Thai-Style Tofu Lettuce Cups',
                'description' => 'Crumbled tofu in a savory lime-soy glaze, scooped into crisp lettuce leaves for a light lunch.',
                'instructions' => "1. Press firm tofu; crumble into bite-sized pieces.\n2. Stir-fry tofu in oil until golden; add minced garlic and ginger.\n3. Add soy sauce, lime juice, a touch of maple syrup, and optional chili paste.\n4. Cook until saucy and absorbed; stir in sliced green onions.\n5. Spoon into lettuce cups; top with peanuts or cilantro.",
                'prep_time' => 28,
            ],
            [
                'user_id' => $userId,
                'category_id' => $petSafeId,
                'title' => 'Pet-Safe Peanut Butter Pumpkin Bites',
                'description' => 'Simple oven treats with oat flour and pumpkin—check that peanut butter is xylitol-free; ask your vet for portion guidance.',
                'instructions' => "1. Preheat oven to 165°C (325°F). Use xylitol-free peanut butter only.\n2. Mix oat flour, pumpkin purée, egg, and a small spoon of peanut butter into a dough.\n3. Roll out between parchment to ½ cm thickness; cut small shapes.\n4. Bake 18–22 minutes until dry at the edges.\n5. Cool completely before offering a small piece; store extras in the fridge up to a week.",
                'prep_time' => 40,
            ],
        ];
    }
}
