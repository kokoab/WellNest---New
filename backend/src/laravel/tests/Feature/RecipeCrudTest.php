<?php

namespace Tests\Feature;

use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RecipeCrudTest extends TestCase
{
    use RefreshDatabase;

    // POST /api/recipes

    public function test_post_recipes_authenticated_user_can_create(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/recipes', [
            'category_id' => $category->id,
            'title' => 'Simple Oats',
            'description' => 'A very simple breakfast.',
            'instructions' => 'Boil water, add oats.',
            'prep_time' => 10,
            'ingredients' => [
                ['name' => 'Oats', 'amount' => '1 cup'],
                ['name' => 'Water', 'amount' => '2 cups'],
            ],
        ]);

        $response->assertCreated()->assertJsonStructure(['message', 'id']);
        $recipeId = $response->json('id');
        $this->assertDatabaseHas('recipes', [
            'id' => $recipeId,
            'user_id' => $user->id,
            'title' => 'Simple Oats',
        ]);
        $this->assertDatabaseCount('recipe_ingredients', 2);
    }

    public function test_post_recipes_authenticated_user_can_create_with_steps(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/recipes', [
            'category_id' => $category->id,
            'title' => 'Step Soup',
            'description' => 'Structured steps.',
            'prep_timing_mode' => 'overall',
            'prep_time' => 25,
            'steps' => [
                ['title' => 'Chop', 'instructions' => 'Dice onions'],
                ['title' => 'Simmer', 'instructions' => 'Cook on low heat'],
            ],
            'ingredients' => [['name' => 'Onion']],
        ]);

        $response->assertCreated()->assertJsonStructure(['message', 'id']);
        $recipeId = $response->json('id');
        $this->assertSame(2, \App\Models\RecipeStep::where('recipe_id', $recipeId)->count());
    }

    public function test_post_recipes_guest_is_unauthorized(): void
    {
        $category = $this->createCategory();

        $this->postJson('/api/recipes', [
            'category_id' => $category->id,
            'title' => 'Guest',
        ])->assertUnauthorized();
    }

    // GET /api/recipes & GET /api/recipes/{recipe}

    public function test_get_recipes_authenticated_user_can_list(): void
    {
        $viewer = $this->createUser();
        $owner = $this->createUser();
        $category = $this->createCategory();
        $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'title' => 'Tomato Soup',
        ]);
        Sanctum::actingAs($viewer);

        $this->getJson('/api/recipes')
            ->assertOk()
            ->assertJsonFragment(['title' => 'Tomato Soup']);
    }

    public function test_get_recipe_authenticated_user_can_show(): void
    {
        $viewer = $this->createUser();
        $owner = $this->createUser();
        $category = $this->createCategory();
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'title' => 'Tomato Soup',
            'instructions' => 'Boil tomatoes and blend.',
            'prep_time' => 20,
        ]);
        Sanctum::actingAs($viewer);

        $this->getJson("/api/recipes/{$recipe->id}")
            ->assertOk()
            ->assertJsonFragment(['id' => $recipe->id, 'title' => 'Tomato Soup']);
    }

    public function test_get_recipes_guest_is_unauthorized(): void
    {
        $this->getJson('/api/recipes')->assertUnauthorized();
    }

    // PUT /api/recipes/{recipe}

    public function test_put_recipe_owner_can_update(): void
    {
        $owner = $this->createUser();
        $category = $this->createCategory();
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'title' => 'Original Title',
            'instructions' => 'Initial instructions.',
            'prep_time' => 15,
        ]);
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

    public function test_put_recipe_non_owner_is_forbidden(): void
    {
        $owner = $this->createUser();
        $otherUser = $this->createUser();
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $this->createCategory()->id,
        ]);
        Sanctum::actingAs($otherUser);

        $this->putJson("/api/recipes/{$recipe->id}", ['title' => 'Hacked Title'])
            ->assertForbidden();
    }

    public function test_put_recipe_guest_is_unauthorized(): void
    {
        $recipe = $this->createRecipe(['user_id' => $this->createUser()->id]);

        $this->putJson("/api/recipes/{$recipe->id}", ['title' => 'Hacked'])
            ->assertUnauthorized();
    }

    // DELETE /api/recipes/{recipe}

    public function test_delete_recipe_owner_can_delete(): void
    {
        $owner = $this->createUser();
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $this->createCategory()->id,
        ]);
        Sanctum::actingAs($owner);

        $this->deleteJson("/api/recipes/{$recipe->id}")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Recipe deleted successfully']);

        $this->assertDatabaseMissing('recipes', ['id' => $recipe->id]);
    }

    public function test_delete_recipe_non_owner_is_forbidden(): void
    {
        $owner = $this->createUser();
        $other = $this->createUser();
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $this->createCategory()->id,
        ]);
        Sanctum::actingAs($other);

        $this->deleteJson("/api/recipes/{$recipe->id}")->assertForbidden();
    }

    public function test_delete_recipe_guest_is_unauthorized(): void
    {
        $recipe = $this->createRecipe(['user_id' => $this->createUser()->id]);

        $this->deleteJson("/api/recipes/{$recipe->id}")->assertUnauthorized();
    }
}
