<?php

namespace Tests\Feature;

use App\Models\RecipeRating;
use App\Models\RecipeView;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RecipeRankingTest extends TestCase
{
    use RefreshDatabase;

    // GET /api/recipes/rankings

    public function test_get_recipe_rankings_authenticated_user_sees_combined_sort(): void
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
        $viewer = $this->createUser(['email' => 'viewer@example.com']);

        RecipeRating::create(['recipe_id' => $topRecipe->id, 'user_id' => $owner->id, 'rating' => 5, 'comment' => 'A']);
        RecipeRating::create(['recipe_id' => $secondRecipe->id, 'user_id' => $owner->id, 'rating' => 3, 'comment' => 'B']);
        RecipeView::create(['recipe_id' => $topRecipe->id, 'user_id' => $owner->id, 'view_date' => now()->toDateString()]);
        RecipeView::create(['recipe_id' => $topRecipe->id, 'user_id' => $viewer->id, 'view_date' => now()->toDateString()]);
        RecipeView::create(['recipe_id' => $secondRecipe->id, 'user_id' => $viewer->id, 'view_date' => now()->toDateString()]);

        Sanctum::actingAs($viewer);

        $response = $this->getJson('api/recipes/rankings?mode=combined&window=all');

        $response->assertOk()
            ->assertJsonPath('data.0.title', 'Top Recipe')
            ->assertJsonFragment(['title' => 'Second Recipe']);
    }

    public function test_get_recipe_rankings_authenticated_user_sees_ratings_mode(): void
    {
        $owner = $this->createUser();
        $category = $this->createCategory();
        $high = $this->createRecipe(['user_id' => $owner->id, 'category_id' => $category->id, 'title' => 'HighRated']);
        $low = $this->createRecipe(['user_id' => $owner->id, 'category_id' => $category->id, 'title' => 'LowRated']);
        $rater = $this->createUser(['email' => 'rater-rank@example.com']);

        RecipeRating::create(['recipe_id' => $high->id, 'user_id' => $rater->id, 'rating' => 5, 'comment' => 'a']);
        RecipeRating::create(['recipe_id' => $low->id, 'user_id' => $rater->id, 'rating' => 2, 'comment' => 'b']);
        RecipeView::create(['recipe_id' => $high->id, 'user_id' => $rater->id, 'view_date' => now()->toDateString()]);
        RecipeView::create(['recipe_id' => $low->id, 'user_id' => $rater->id, 'view_date' => now()->toDateString()]);

        Sanctum::actingAs($this->createUser());

        $titles = collect($this->getJson('api/recipes/rankings?mode=ratings&window=all')->json('data'))
            ->pluck('title')->all();

        $this->assertSame('HighRated', $titles[0]);
    }

    public function test_get_recipe_rankings_guest_is_unauthorized(): void
    {
        $this->getJson('api/recipes/rankings')->assertUnauthorized();
    }
}
