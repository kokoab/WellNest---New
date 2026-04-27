<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Recipe;
use App\Models\User;
use App\Models\Ingredient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;
use Illuminate\Support\Facades\Hash;

class RecipeInteractionTest extends TestCase
{
    use RefreshDatabase;

    private function createUser(array $overrides = []): User
    {
        return User::create(array_merge([
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => 'test@example.com',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'account_status' => 'active',
            'is_admin' => false,
        ], $overrides));
    }

    private function createCategory(): Category
    {
        return Category::create([
            'name' => 'Main Course',
            'description' => 'Main meals',
        ]);
    }

    private function createRecipe(User $user, Category $category): Recipe
    {
        return Recipe::create([
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Test Recipe',
            'instructions' => 'Follow steps.',
            'prep_time' => 15,
        ]);
    }

    public function test_create_recipe_fails_validation_on_missing_fields(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('api/recipes', []);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['title', 'instructions', 'category_id']);
    }

    public function test_unauthorized_user_cannot_update_recipe(): void
    {
        $owner = $this->createUser(['email' => 'owner@example.com']);
        $otherUser = $this->createUser(['email' => 'other@example.com']);
        $category = $this->createCategory();
        $recipe = $this->createRecipe($owner, $category);

        Sanctum::actingAs($otherUser);

        $response = $this->putJson("api/recipes/{$recipe->id}", [
            'title' => 'Updated Title'
        ]);

        $response->assertStatus(403);
    }

    public function test_unauthorized_user_cannot_delete_recipe(): void
    {
        $owner = $this->createUser(['email' => 'owner@example.com']);
        $otherUser = $this->createUser(['email' => 'other@example.com']);
        $category = $this->createCategory();
        $recipe = $this->createRecipe($owner, $category);

        Sanctum::actingAs($otherUser);

        $response = $this->deleteJson("api/recipes/{$recipe->id}");

        $response->assertStatus(403);
    }

    public function test_user_can_rate_a_recipe(): void
    {
        $user = $this->createUser();
        $owner = $this->createUser(['email' => 'owner@example.com']);
        $category = $this->createCategory();
        $recipe = $this->createRecipe($owner, $category);

        Sanctum::actingAs($user);

        $response = $this->postJson("api/recipes/{$recipe->id}/ratings", [
            'rating' => 5,
            'comment' => 'Great recipe!'
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('recipe_ratings', [
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'rating' => 5
        ]);
    }

    public function test_user_can_save_and_unsave_recipe(): void
    {
        $user = $this->createUser();
        $owner = $this->createUser(['email' => 'owner@example.com']);
        $category = $this->createCategory();
        $recipe = $this->createRecipe($owner, $category);

        Sanctum::actingAs($user);

        // Save
        $response = $this->postJson("api/recipes/{$recipe->id}/save");
        $response->assertSuccessful();
        $this->assertDatabaseHas('saved_recipes', [
            'user_id' => $user->id,
            'recipe_id' => $recipe->id
        ]);

        // Unsave
        $response = $this->deleteJson("api/recipes/{$recipe->id}/save");
        $response->assertOk();
        $this->assertDatabaseMissing('saved_recipes', [
            'user_id' => $user->id,
            'recipe_id' => $recipe->id
        ]);
    }

    public function test_fetch_ingredients_for_a_recipe(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();
        $recipe = $this->createRecipe($user, $category);
        $ingredient = Ingredient::create(['name' => 'Salt']);
        
        $recipe->ingredients()->attach($ingredient->id, ['quantity' => '1', 'unit' => 'tsp']);

        $response = $this->getJson("api/recipes/{$recipe->id}");

        $response->assertOk()
            ->assertJsonFragment(['name' => 'Salt']);
    }

    public function test_recipe_view_incrementing(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();
        $recipe = $this->createRecipe($user, $category);

        Sanctum::actingAs($user);

        // Accessing the recipe should log a view
        $this->getJson("api/recipes/{$recipe->id}");

        $this->assertDatabaseHas('recipe_views', [
            'recipe_id' => $recipe->id
        ]);
    }
}
