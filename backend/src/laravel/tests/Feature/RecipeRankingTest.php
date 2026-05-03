<?php

namespace Tests\Feature;

use App\Models\RecipeRating;
use App\Models\RecipeView;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RecipeRankingTest extends TestCase
{
    use RefreshDatabase;

    public function test_recipe_rankings_return_sorted_recipes(): void
    {
        $owner = $this->createUser();
        $category = $this->createCategory();

        $topRecipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'title' => 'Top Recipe',
        ]);
        $secondRecipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'title' => 'Second Recipe',
        ]);
        $secondUser = $this->createUser([
            'email' => 'viewer@example.com',
        ]);

        RecipeRating::create([
            'recipe_id' => $topRecipe->id,
            'user_id' => $owner->id,
            'rating' => 5,
            'comment' => 'Excellent',
        ]);
        RecipeRating::create([
            'recipe_id' => $secondRecipe->id,
            'user_id' => $owner->id,
            'rating' => 3,
            'comment' => 'Okay',
        ]);

        RecipeView::create([
            'recipe_id' => $topRecipe->id,
            'user_id' => $owner->id,
            'view_date' => now()->toDateString(),
        ]);
        RecipeView::create([
            'recipe_id' => $topRecipe->id,
            'user_id' => $secondUser->id,
            'view_date' => now()->toDateString(),
        ]);
        RecipeView::create([
            'recipe_id' => $secondRecipe->id,
            'user_id' => $secondUser->id,
            'view_date' => now()->toDateString(),
        ]);

        $response = $this->getJson('api/recipes/rankings?mode=combined&window=all');

        $response->assertOk()
            ->assertJsonPath('data.0.title', 'Top Recipe')
            ->assertJsonFragment(['title' => 'Second Recipe']);
    }
}