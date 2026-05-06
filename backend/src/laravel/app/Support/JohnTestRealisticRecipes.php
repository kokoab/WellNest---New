<?php

namespace App\Support;

use App\Models\Ingredient;
use App\Models\Recipe;
use App\Models\RecipeIngredient;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;

/**
 * Seeds realistic demo recipes for QA user “john test”, including downloaded photos.
 */
class JohnTestRealisticRecipes
{
    /** @var list<string> */
    private static array $ingredientPool = [
        'Olive oil', 'Sea salt', 'Black pepper', 'Garlic', 'Yellow onion',
        'Lemon juice', 'Butter', 'Eggs', 'Whole milk', 'All-purpose flour',
        'Cherry tomatoes', 'Fresh basil', 'Parmesan cheese', 'Chicken stock',
        'Heavy cream', 'Jasmine rice', 'Dry pasta', 'Soy sauce', 'Honey',
        'Greek yogurt', 'Avocado', 'Baby spinach', 'Cremini mushrooms',
        'Red bell pepper', 'Sharp cheddar', 'Smoked paprika', 'Cumin',
        'Fresh cilantro', 'Lime', 'Maple syrup', 'Brown sugar', 'Thyme',
    ];

    /**
     * Ensure at least $minimum recipes owned by $user have one gallery image (photo or SVG fallback).
     *
     * @return int Number of new recipes created
     */
    public static function seedPhotographedRecipes(User $user, Collection $categories, int $minimum): int
    {
        if ($minimum <= 0 || $categories->isEmpty()) {
            return 0;
        }

        $have = Recipe::where('user_id', $user->id)->whereHas('images')->count();
        $need = max(0, $minimum - $have);
        if ($need === 0) {
            return 0;
        }

        $templates = self::templates();
        $templateCount = count($templates);
        $created = 0;
        $existingRecipeCount = Recipe::where('user_id', $user->id)->count();

        for ($i = 0; $i < $need; $i++) {
            $tpl = $templates[($i + $existingRecipeCount) % $templateCount];

            $recipe = Recipe::query()->create([
                'user_id' => $user->id,
                'category_id' => $categories->random()->id,
                'title' => $tpl['title'],
                'description' => $tpl['description'],
                'instructions' => $tpl['instructions'],
                'prep_time' => random_int(12, 95),
            ]);

            self::attachIngredients($recipe);
            self::attachPhotoFromUrl($recipe, $tpl['photo']);
            $created++;
        }

        return $created;
    }

    private static function attachIngredients(Recipe $recipe): void
    {
        $count = random_int(4, min(7, count(self::$ingredientPool)));
        foreach (collect(self::$ingredientPool)->shuffle()->take($count) as $name) {
            $ingredient = Ingredient::firstOrCreate(['name' => $name]);
            RecipeIngredient::query()->create([
                'recipe_id' => $recipe->id,
                'ingredient_id' => $ingredient->id,
                'quantity' => random_int(1, 4),
                'unit' => collect(['tbsp', 'tsp', 'cup', 'g', 'ml', 'pieces'])->random(),
            ]);
        }
    }

    private static function attachPhotoFromUrl(Recipe $recipe, string $url): void
    {
        try {
            $response = Http::timeout(60)
                ->withHeaders(['User-Agent' => 'WellNestDemoSeeder/1.0'])
                ->get($url);

            if ($response->successful()) {
                $body = $response->body();
                if (strlen($body) > 2000) {
                    $path = 'recipes/john_demo/'.$recipe->id.'_'.uniqid('', true).'.jpg';
                    Storage::disk('public')->put($path, $body);
                    $recipe->images()->create(['path' => $path]);

                    return;
                }
            }
        } catch (\Throwable) {
            // Fall back below.
        }

        RecipePlaceholderImage::ensureForRecipe($recipe);
    }

    /**
     * Curated titles + Unsplash food photography (hotlinked download into storage at seed time).
     *
     * @return list<array{title:string,description:string,instructions:string,photo:string}>
     */
    private static function templates(): array
    {
        return [
            [
                'title' => 'Pan-Seared Salmon With Lemon Butter',
                'description' => 'Restaurant-style salmon with crisp edges and a silky citrus pan sauce.',
                'instructions' => 'Pat salmon dry, sear skin-side down in a hot oiled skillet until crisp. Flip briefly, finish with butter, lemon, and parsley.',
                'photo' => 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Classic Margherita Pizza',
                'description' => 'Thin crust, bright tomato, milky mozzarella, and fresh basil.',
                'instructions' => 'Stretch dough, top with crushed tomatoes and torn mozzarella. Bake at maximum oven heat until blistered; finish with basil leaves.',
                'photo' => 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Hearty Vegetable Soup',
                'description' => 'A comforting bowl packed with seasonal vegetables and herbs.',
                'instructions' => 'Sauté aromatics, add chopped vegetables and stock, simmer until tender. Season and serve with crusty bread.',
                'photo' => 'https://images.unsplash.com/photo-1547592166-23abf45744cd?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Grilled Steak With Chimichurri',
                'description' => 'Smoky crust, juicy center, and herby Argentine-style sauce.',
                'instructions' => 'Season steak generously; grill or sear to desired doneness. Rest, slice against the grain, spoon chimichurri on top.',
                'photo' => 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Avocado Toast With Radish',
                'description' => 'Crunchy, creamy, and bright — perfect for brunch.',
                'instructions' => 'Toast bread, mash avocado with lime and salt. Top with sliced radish, chili flakes, and olive oil.',
                'photo' => 'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Thai Green Curry With Jasmine Rice',
                'description' => 'Coconut curry with tender vegetables and fragrant rice.',
                'instructions' => 'Simmer curry paste with coconut milk, add vegetables and protein; finish with basil. Serve over steamed jasmine rice.',
                'photo' => 'https://images.unsplash.com/photo-1455619450894-d96387448991?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Berry Yogurt Parfait',
                'description' => 'Layers of yogurt, honey, granola, and fresh berries.',
                'instructions' => 'Layer yogurt, berries, and granola in glasses; drizzle honey between layers. Chill briefly before serving.',
                'photo' => 'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Garlic Butter Shrimp Pasta',
                'description' => 'Quick weeknight pasta with tender shrimp and lemon garlic sauce.',
                'instructions' => 'Cook pasta. Sauté shrimp with garlic, chili, and butter; toss with pasta water for a silky sauce.',
                'photo' => 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Roasted Vegetable Grain Bowl',
                'description' => 'Colorful roasted veg over grains with a tangy dressing.',
                'instructions' => 'Roast seasoned vegetables until caramelized. Serve over quinoa or rice with yogurt-lemon dressing.',
                'photo' => 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Banana Oat Pancakes',
                'description' => 'Fluffy pancakes sweetened naturally with ripe bananas.',
                'instructions' => 'Mash bananas into batter with oats and eggs. Cook on a buttered griddle until golden; top with maple syrup.',
                'photo' => 'https://images.unsplash.com/photo-1528207776546-365bb710ee93?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Caprese Salad Skewers',
                'description' => 'Tomato, mozzarella, and basil bites drizzled with balsamic.',
                'instructions' => 'Thread cherry tomatoes, mozzarella, and basil onto skewers. Drizzle olive oil and balsamic glaze.',
                'photo' => 'https://images.unsplash.com/photo-1608897013039-887f21d8c804?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Chicken Tikka Masala',
                'description' => 'Grilled spiced chicken in a creamy tomato curry sauce.',
                'instructions' => 'Marinate chicken in yogurt and spices; grill or broil. Simmer in tomato-cream masala sauce until glossy.',
                'photo' => 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Beef Tacos With Pickled Onions',
                'description' => 'Street-style tacos with seasoned beef and bright pickles.',
                'instructions' => 'Brown seasoned beef; warm tortillas. Top with salsa, pickled onions, cilantro, and lime.',
                'photo' => 'https://images.unsplash.com/photo-1565299585323-38174c3bfe65?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Mediterranean Chickpea Salad',
                'description' => 'Protein-rich salad with cucumber, feta, olives, and herbs.',
                'instructions' => 'Combine chickpeas with chopped vegetables, feta, and lemon vinaigrette. Chill 20 minutes for flavors to meld.',
                'photo' => 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Chocolate Chip Cookies',
                'description' => 'Chewy centers, crisp edges, and loads of chocolate chunks.',
                'instructions' => 'Cream butter and sugars, mix dry ingredients, fold chocolate. Chill dough; bake until golden at edges.',
                'photo' => 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Egg Fried Rice',
                'description' => 'Smoky wok rice with egg, peas, and scallions.',
                'instructions' => 'Stir-fry cold rice with egg and aromatics; season with soy sauce and sesame oil; finish with scallions.',
                'photo' => 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'French Onion Soup',
                'description' => 'Slow-caramelized onions in rich broth with cheesy toast.',
                'instructions' => 'Caramelize onions deeply. Add stock and simmer; top bowls with toast and melted Gruyère.',
                'photo' => 'https://images.unsplash.com/photo-1608219992759-8d74ed8d76eb?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Spinach And Feta Stuffed Chicken',
                'description' => 'Juicy chicken breasts filled with greens and tangy cheese.',
                'instructions' => 'Stuff pockets with spinach-feta mixture; sear then roast until cooked through.',
                'photo' => 'https://images.unsplash.com/photo-1598515214210-67cc24ec84ec?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Spiced Lentil Dahl',
                'description' => 'Creamy red lentils with ginger, turmeric, and tomatoes.',
                'instructions' => 'Bloom spices, simmer lentils until creamy; finish with cilantro and a squeeze of lime.',
                'photo' => 'https://images.unsplash.com/photo-1585937421612-70a008356f36?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Caesar Salad With Croutons',
                'description' => 'Crisp romaine, parmesan, and homemade garlic croutons.',
                'instructions' => 'Toss lettuce with Caesar dressing; add shaved parmesan and crunchy croutons.',
                'photo' => 'https://images.unsplash.com/photo-1550304943-f04eddcae78f?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'BBQ Pulled Pork Sandwich',
                'description' => 'Slow-cooked pork shoulder with smoky sauce on a brioche bun.',
                'instructions' => 'Season pork and slow-roast until shreddable; toss with BBQ sauce; pile onto buns with slaw.',
                'photo' => 'https://images.unsplash.com/photo-1529193592818-dfdcb261e008?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Mango Smoothie Bowl',
                'description' => 'Frozen mango blended thick and topped with crunchy granola.',
                'instructions' => 'Blend frozen mango with yogurt until spoon-thick; top with granola, coconut, and chia.',
                'photo' => 'https://images.unsplash.com/photo-1490474418585-ba3573c38add?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Crispy Fish Tacos With Slaw',
                'description' => 'Beer-battered fish with crunchy cabbage slaw and lime crema.',
                'instructions' => 'Fry battered fish until crisp; warm tortillas; layer fish, slaw, and crema.',
                'photo' => 'https://images.unsplash.com/photo-1512058564365-18510be2db19?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Mushroom Risotto',
                'description' => 'Creamy arborio rice with earthy mushrooms and parmesan.',
                'instructions' => 'Toast rice, add warm stock gradually while stirring; fold in sautéed mushrooms and parmesan.',
                'photo' => 'https://images.unsplash.com/photo-1476124369491-e7dd712032dd?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Homemade Beef Burger',
                'description' => 'Juicy patty with caramelized onions and melted cheese.',
                'instructions' => 'Form patties with salt and pepper; grill or skillet-cook; toast buns; assemble with toppings.',
                'photo' => 'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Spring Rolls With Peanut Sauce',
                'description' => 'Fresh herbs and vegetables wrapped in rice paper.',
                'instructions' => 'Soften wrappers, fill with veggies and herbs; roll tightly; serve with peanut dipping sauce.',
                'photo' => 'https://images.unsplash.com/photo-1534422298391-e4f8c172789a?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Garlic Parmesan Wings',
                'description' => 'Crispy baked wings tossed in garlic butter and parmesan.',
                'instructions' => 'Bake wings until crisp; toss with garlic butter, parmesan, and parsley.',
                'photo' => 'https://images.unsplash.com/photo-1527477391520-514fcb588eea?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Berry Smoothie',
                'description' => 'Cold blended berries with banana and yogurt.',
                'instructions' => 'Blend frozen berries, banana, yogurt, and milk until smooth; sweeten to taste.',
                'photo' => 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Chicken Caesar Wrap',
                'description' => 'Grilled chicken and romaine rolled in a tortilla with parmesan.',
                'instructions' => 'Grill chicken strips; toss lettuce with Caesar dressing; wrap tightly in tortillas.',
                'photo' => 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Pumpkin Soup With Seeds',
                'description' => 'Silky roasted pumpkin soup topped with toasted seeds.',
                'instructions' => 'Roast pumpkin; blend with stock and spices; garnish with cream and toasted seeds.',
                'photo' => 'https://images.unsplash.com/photo-1476718406336-bb5a9690ee2a?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Seafood Paella',
                'description' => 'Saffron rice with shrimp, mussels, and peas.',
                'instructions' => 'Build socarrat in a wide pan; nestle seafood; steam until shells open and rice is tender.',
                'photo' => 'https://images.unsplash.com/photo-1534080564583-6be75777b70a?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Vegetable Stir-Fry',
                'description' => 'Quick high-heat vegetables with ginger soy glaze.',
                'instructions' => 'Stir-fry vegetables in batches; combine with aromatics and soy glaze; serve over rice.',
                'photo' => 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Classic Cheeseburger With Fries',
                'description' => 'American diner-style burger with golden fries.',
                'instructions' => 'Cook patties and fries in parallel; assemble burger with lettuce, tomato, onion, and pickles.',
                'photo' => 'https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Apple Cinnamon Oatmeal',
                'description' => 'Warm oats with sautéed apples and cinnamon.',
                'instructions' => 'Simmer oats with milk; sauté apples with cinnamon and maple; fold together.',
                'photo' => 'https://images.unsplash.com/photo-1517673132405-a56a62b18caf?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Tomato Basil Bruschetta',
                'description' => 'Toasted bread rubbed with garlic and topped with tomato basil salad.',
                'instructions' => 'Dice tomatoes with basil, olive oil, and vinegar; spoon onto toasted bread.',
                'photo' => 'https://images.unsplash.com/photo-1572449043416-55f468260c91?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Sticky Korean BBQ Wings',
                'description' => 'Sweet-spicy glaze with sesame and scallions.',
                'instructions' => 'Bake wings until crisp; toss in reduced soy-gochujang glaze; garnish with sesame.',
                'photo' => 'https://images.unsplash.com/photo-1608039829572-78524f79cceb?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Charred Corn Salad',
                'description' => 'Smoky corn kernels with lime, cotija, and chili.',
                'instructions' => 'Char corn in a skillet; toss with lime, cheese, chili powder, and cilantro.',
                'photo' => 'https://images.unsplash.com/photo-1604908177446-13e54899ade3?auto=format&fit=crop&w=1200&q=80',
            ],
            [
                'title' => 'Ratatouille Bake',
                'description' => 'Layered summer vegetables baked with herbs and olive oil.',
                'instructions' => 'Slice vegetables thin; layer with tomato sauce; bake until tender and glossy.',
                'photo' => 'https://images.unsplash.com/photo-1572695157366-5e585ab2b69f?auto=format&fit=crop&w=1200&q=80',
            ],
        ];
    }
}
