<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Recipe;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RecipeInteractionTest extends TestCase
{
    use RefreshDatabase;

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
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
        ]);

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
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
        ]);

        Sanctum::actingAs($otherUser);

        $response = $this->deleteJson("api/recipes/{$recipe->id}");

        $response->assertStatus(403);
    }

    public function test_user_can_rate_a_recipe(): void
    {
        $user = $this->createUser();
        $owner = $this->createUser(['email' => 'owner@example.com']);
        $category = $this->createCategory();
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
        ]);

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

    public function test_user_can_update_their_existing_recipe_rating(): void
    {
        $user = $this->createUser();
        $owner = $this->createUser(['email' => 'owner-update@example.com']);
        $category = $this->createCategory();
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
        ]);

        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/ratings", [
            'rating' => 3,
            'comment' => 'Okay recipe',
        ])->assertCreated();

        $response = $this->postJson("api/recipes/{$recipe->id}/ratings", [
            'rating' => 5,
            'comment' => 'Much better now',
        ]);

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Rating updated']);

        $this->assertDatabaseHas('recipe_ratings', [
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'rating' => 5,
            'comment' => 'Much better now',
        ]);
    }

    public function test_user_can_save_and_unsave_recipe(): void
    {
        $user = $this->createUser();
        $owner = $this->createUser(['email' => 'owner@example.com']);
        $category = $this->createCategory();
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
        ]);

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
        $recipe = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
        ]);
        $ingredient = $this->createIngredient(['name' => 'Salt']);

        $recipe->ingredients()->attach($ingredient->id, ['quantity' => '1', 'unit' => 'tsp']);

        $response = $this->getJson("api/recipes/{$recipe->id}");

        $response->assertOk()
            ->assertJsonFragment(['name' => 'Salt']);
    }

    public function test_recipe_view_incrementing(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();
        $recipe = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
        ]);

        Sanctum::actingAs($user);

        $this->getJson("api/recipes/{$recipe->id}");

        $this->assertDatabaseHas('recipe_views', [
            'recipe_id' => $recipe->id
        ]);
    }

    public function test_user_can_view_their_own_recipe_rating(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory();
        $recipe = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
        ]);

        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/ratings", [
            'rating' => 4,
            'comment' => 'Good recipe',
        ])->assertCreated();

        $response = $this->getJson("api/recipes/{$recipe->id}/ratings/me");

        $response->assertOk()
            ->assertJsonPath('rating.rating', 4)
            ->assertJsonPath('rating.comment', 'Good recipe');
    }

    public function test_recipe_image_can_be_uploaded_by_owner(): void
    {
        Storage::fake('public');

        $owner = $this->createUser();
        $category = $this->createCategory();
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $category->id,
        ]);

        Sanctum::actingAs($owner);

        $response = $this->postJson("api/recipes/{$recipe->id}/images", [
            'image' => UploadedFile::fake()->create('recipe.jpg', 100, 'image/jpeg'),
        ]);

        $response->assertCreated()
            ->assertJsonFragment(['message' => 'Image uploaded successfully']);

        $this->assertNotEmpty($response->json('image.image_url'));
    }
}
