<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Recipe;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class RecipeCrudTest extends TestCase
{
    use RefreshDatabase;

    private function createUser(array $overrides = []): User
    {
        return User::create(array_merge([
            'first_name' => 'Recipe',
            'last_name' => 'Owner',
            'email' => 'owner@example.com',
            'password' => Hash::make('password123'),
            'role' => 'user',
            'status' => 'active',
            'is_admin' => false,
        ], $overrides));
    }

    private function createCategory(): Category
    {
        return Category::create([
            'name' => 'Breakfast',
            'description' => 'Morning meals',
        ]);
    }

    private function recipePayload(int $categoryId): array
    {
        return [
            'category_id' => $categoryId,
            'title' => 'Simple Oats',
            'instructions' => 'Mix oats with milk and rest overnight.',
            'prep_time' => 10,
            'ingredients' => [
                ['name' => 'Oats', 'quantity' => 1, 'unit' => 'cup'],
                ['name' => 'Milk', 'quantity' => 1, 'unit' => 'cup'],
            ],
        ];
    }

    public function test_authenticated_user_can_create_recipe(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/recipes', $this->recipePayload($category->id));

        $response->assertCreated()
            ->assertJsonStructure(['message', 'id']);

        $recipeId = $response->json('id');
        $this->assertDatabaseHas('recipes', [
            'id' => $recipeId,
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Simple Oats',
        ]);
        $this->assertDatabaseCount('recipe_ingredients', 2);
    }

    public function test_guest_cannot_create_recipe(): void
    {
        $category = $this->createCategory();

        $response = $this->postJson('/api/recipes', $this->recipePayload($category->id));

        $response->assertUnauthorized();
    }

    public function test_recipe_is_visible_on_public_show_and_index(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();
        $recipe = Recipe::create([
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Tomato Soup',
            'instructions' => 'Boil tomatoes and blend.',
            'prep_time' => 20,
        ]);

        $this->getJson('/api/recipes')
            ->assertOk()
            ->assertJsonFragment(['title' => 'Tomato Soup']);

        $this->getJson("/api/recipes/{$recipe->id}")
            ->assertOk()
            ->assertJsonFragment([
                'id' => $recipe->id,
                'title' => 'Tomato Soup',
            ]);
    }

    public function test_owner_can_update_recipe_but_other_user_cannot(): void
    {
        $owner = $this->createUser(['email' => 'owner1@example.com']);
        $otherUser = $this->createUser(['email' => 'owner2@example.com']);
        $category = $this->createCategory();

        $recipe = Recipe::create([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'title' => 'Original Title',
            'instructions' => 'Initial instructions.',
            'prep_time' => 15,
        ]);

        $this->actingAs($otherUser, 'sanctum')
            ->putJson("/api/recipes/{$recipe->id}", ['title' => 'Hacked Title'])
            ->assertForbidden();

        $this->actingAs($owner, 'sanctum')
            ->putJson("/api/recipes/{$recipe->id}", [
                'title' => 'Updated Title',
                'prep_time' => 25,
            ])
            ->assertOk()
            ->assertJsonFragment(['message' => 'Recipe updated successfully']);

        $this->assertDatabaseHas('recipes', [
            'id' => $recipe->id,
            'title' => 'Updated Title',
            'prep_time' => 25,
        ]);
    }

    public function test_owner_can_delete_recipe(): void
    {
        $owner = $this->createUser();
        $category = $this->createCategory();
        $recipe = Recipe::create([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'title' => 'Delete Me',
            'instructions' => 'Delete this recipe.',
            'prep_time' => 5,
        ]);

        $this->actingAs($owner, 'sanctum')
            ->deleteJson("/api/recipes/{$recipe->id}")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Recipe deleted successfully']);

        $this->assertDatabaseMissing('recipes', ['id' => $recipe->id]);
    }
}

