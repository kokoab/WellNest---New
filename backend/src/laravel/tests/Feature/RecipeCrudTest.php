<?php

namespace Tests\Feature;

use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;



class RecipeCrudTest extends TestCase
{
    use RefreshDatabase;


    public function test_authenticated_user_can_create_recipe(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();

        $recipe = [
            'category_id' => $category->id,
            'title' => 'Simple Oats',
            'description' => 'A very simple breakfast.',
            'instructions' => 'Boil water, add oats.',
            'prep_time' => 10,
            'ingredients' => [
                ['name' => 'Oats', 'amount' => '1 cup'],
                ['name' => 'Water', 'amount' => '2 cups'],
            ],
        ];

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/recipes", $recipe);

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

    public function test_authenticated_user_can_create_recipe_with_structured_steps(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();

        Sanctum::actingAs($user);

        $payload = [
            'category_id' => $category->id,
            'title' => 'Step Soup',
            'description' => 'Structured steps.',
            'prep_timing_mode' => 'overall',
            'prep_time' => 25,
            'steps' => [
                ['title' => 'Chop', 'instructions' => 'Dice onions'],
                ['title' => 'Simmer', 'instructions' => 'Cook on low heat'],
            ],
            'ingredients' => [
                ['name' => 'Onion', 'quantity' => 1, 'unit' => 'whole'],
            ],
        ];

        $response = $this->postJson('/api/recipes', $payload);

        $response->assertCreated()->assertJsonStructure(['message', 'id']);

        $recipeId = $response->json('id');

        $this->assertDatabaseHas('recipe_steps', ['recipe_id' => $recipeId]);
        $this->assertSame(2, \App\Models\RecipeStep::where('recipe_id', $recipeId)->count());

        $show = $this->getJson("/api/recipes/{$recipeId}");
        $show->assertOk()->assertJsonPath('prep_timing_mode', 'overall');
        $steps = $show->json('steps');
        $this->assertIsArray($steps);
        $this->assertCount(2, $steps);
    }

    public function test_guest_cannot_create_recipe(): void
    {
        $category = $this->createCategory();

        $recipe = [
            'category_id' => $category->id,
            'title' => 'Guest',
        ];

        $response = $this->postJson('/api/recipes', $recipe);

        $response->assertUnauthorized();
    }

    public function test_recipe_is_visible_on_public_show_and_index(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();
        $recipe = $this->createRecipe([
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

        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'title' => 'Original Title',
            'instructions' => 'Initial instructions.',
            'prep_time' => 15,
        ]);

        Sanctum::actingAs($otherUser);
        $this->putJson("/api/recipes/{$recipe->id}", ['title' => 'Hacked Title'])
            ->assertForbidden();

        Sanctum::actingAs($owner);
        $this->putJson("/api/recipes/{$recipe->id}", [
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
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
        ]);

        Sanctum::actingAs($owner);
        $this->deleteJson("/api/recipes/{$recipe->id}")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Recipe deleted successfully']);

        $this->assertDatabaseMissing('recipes', ['id' => $recipe->id]);
    }
}
