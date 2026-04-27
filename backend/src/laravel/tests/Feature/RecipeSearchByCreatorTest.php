<?php

namespace Tests\Feature;

use App\Models\Recipe;
use App\Models\User;
use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RecipeSearchByCreatorTest extends TestCase
{
    use RefreshDatabase;

    public function test_can_search_recipes_by_creator_first_name()
    {
        $creator = User::factory()->create(['first_name' => 'Gordon', 'last_name' => 'Ramsay']);
        $category = Category::factory()->create();
        
        Recipe::factory()->create([
            'user_id' => $creator->id,
            'category_id' => $category->id,
            'title' => 'Beef Wellington'
        ]);

        $response = $this->getJson('/api/recipes?search=Gordon');

        $response->assertStatus(200)
                 ->assertJsonCount(1, 'data')
                 ->assertJsonPath('data.0.title', 'Beef Wellington');
    }

    public function test_can_search_recipes_by_creator_last_name()
    {
        $creator = User::factory()->create(['first_name' => 'Gordon', 'last_name' => 'Ramsay']);
        $category = Category::factory()->create();
        
        Recipe::factory()->create([
            'user_id' => $creator->id,
            'category_id' => $category->id,
            'title' => 'Scrambled Eggs'
        ]);

        $response = $this->getJson('/api/recipes?search=Ramsay');

        $response->assertStatus(200)
                 ->assertJsonCount(1, 'data')
                 ->assertJsonPath('data.0.title', 'Scrambled Eggs');
    }

    public function test_search_matches_both_title_and_creator()
    {
        $creator = User::factory()->create(['first_name' => 'Pasta', 'last_name' => 'Master']);
        $category = Category::factory()->create();
        
        // Match by creator name
        Recipe::factory()->create([
            'user_id' => $creator->id,
            'category_id' => $category->id,
            'title' => 'Basic Dish'
        ]);

        // Match by title
        Recipe::factory()->create([
            'user_id' => User::factory()->create()->id,
            'category_id' => $category->id,
            'title' => 'Creamy Pasta'
        ]);

        $response = $this->getJson('/api/recipes?search=Pasta');

        $response->assertStatus(200)
                 ->assertJsonCount(2, 'data');
    }
}
