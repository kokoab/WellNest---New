<?php

namespace Tests\Feature;

use App\Models\Recipe;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RecipeInteractionTest extends TestCase
{
    use RefreshDatabase;

    // POST /api/recipes/{recipe}/ratings

    public function test_post_recipe_rating_authenticated_user_can_rate(): void
    {
        $user = $this->createUser();
        $owner = $this->createUser(['email' => 'owner@example.com']);
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $this->createCategory()->id,
        ]);
        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/ratings", [
            'rating' => 5,
            'comment' => 'Great recipe!',
        ])->assertCreated();

        $this->assertDatabaseHas('recipe_ratings', [
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'rating' => 5,
        ]);
    }

    public function test_post_recipe_rating_authenticated_user_can_update_existing(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $this->createUser(['email' => 'owner-r@example.com'])->id]);
        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/ratings", ['rating' => 3, 'comment' => 'Okay'])->assertCreated();
        $this->postJson("api/recipes/{$recipe->id}/ratings", ['rating' => 5, 'comment' => 'Better'])
            ->assertOk()
            ->assertJsonFragment(['message' => 'Rating updated']);
    }

    public function test_post_recipe_rating_guest_is_unauthorized(): void
    {
        $recipe = $this->createRecipe();

        $this->postJson("api/recipes/{$recipe->id}/ratings", ['rating' => 5])
            ->assertUnauthorized();
    }

    // GET /api/recipes/{recipe}/ratings

    public function test_get_recipe_ratings_authenticated_user_can_list(): void
    {
        $viewer = $this->createUser();
        $recipe = $this->createRecipe();
        $rater = $this->createUser(['email' => 'rater@example.com']);
        $this->createRecipeRating(['recipe_id' => $recipe->id, 'user_id' => $rater->id, 'rating' => 5]);
        Sanctum::actingAs($viewer);

        $this->getJson("api/recipes/{$recipe->id}/ratings")
            ->assertOk()
            ->assertJsonStructure(['data', 'average_rating', 'ratings_count']);
    }

    public function test_get_recipe_ratings_authenticated_user_sees_empty_when_none(): void
    {
        Sanctum::actingAs($this->createUser());
        $recipe = $this->createRecipe();

        $response = $this->getJson("api/recipes/{$recipe->id}/ratings");

        $response->assertOk();
        $this->assertSame([], $response->json('data'));
    }

    public function test_get_recipe_ratings_guest_is_unauthorized(): void
    {
        $this->getJson('api/recipes/'.$this->createRecipe()->id.'/ratings')->assertUnauthorized();
    }

    // GET /api/recipes/{recipe}/ratings/me

    public function test_get_recipe_rating_me_authenticated_user_sees_own_rating(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $user->id, 'category_id' => $this->createCategory()->id]);
        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/ratings", ['rating' => 4, 'comment' => 'Good'])->assertCreated();

        $this->getJson("api/recipes/{$recipe->id}/ratings/me")
            ->assertOk()
            ->assertJsonPath('rating.rating', 4);
    }

    public function test_get_recipe_rating_me_authenticated_user_gets_null_when_none(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->getJson('api/recipes/'.$this->createRecipe()->id.'/ratings/me')
            ->assertOk()
            ->assertJson(['rating' => null]);
    }

    public function test_get_recipe_rating_me_guest_is_unauthorized(): void
    {
        $this->getJson('api/recipes/'.$this->createRecipe()->id.'/ratings/me')->assertUnauthorized();
    }

    // POST /api/recipes/{recipe}/save

    public function test_post_recipe_save_authenticated_user_can_save(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $this->createUser(['email' => 'save-owner@example.com'])->id]);
        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/save")->assertSuccessful();
        $this->assertDatabaseHas('saved_recipes', ['user_id' => $user->id, 'recipe_id' => $recipe->id]);
    }

    public function test_post_recipe_save_idempotent_on_duplicate(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/save")->assertCreated();
        $this->postJson("api/recipes/{$recipe->id}/save")->assertCreated();
        $this->assertDatabaseCount('saved_recipes', 1);
    }

    public function test_post_recipe_save_guest_is_unauthorized(): void
    {
        $this->postJson('api/recipes/'.$this->createRecipe()->id.'/save')->assertUnauthorized();
    }

    // DELETE /api/recipes/{recipe}/save

    public function test_delete_recipe_save_authenticated_user_can_unsave(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe();
        Sanctum::actingAs($user);

        $this->postJson("api/recipes/{$recipe->id}/save")->assertCreated();
        $this->deleteJson("api/recipes/{$recipe->id}/save")->assertOk();
        $this->assertDatabaseMissing('saved_recipes', ['user_id' => $user->id, 'recipe_id' => $recipe->id]);
    }

    public function test_delete_recipe_save_when_not_saved_is_safe(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->deleteJson('api/recipes/'.$this->createRecipe()->id.'/save')->assertOk();
    }

    public function test_delete_recipe_save_guest_is_unauthorized(): void
    {
        $this->deleteJson('api/recipes/'.$this->createRecipe()->id.'/save')->assertUnauthorized();
    }

    // GET /api/recipes/{recipe} (ingredients + view count)

    public function test_get_recipe_authenticated_user_sees_ingredients(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $user->id, 'category_id' => $this->createCategory()->id]);
        $ingredient = $this->createIngredient(['name' => 'Salt']);
        $recipe->ingredients()->attach($ingredient->id);
        Sanctum::actingAs($user);

        $this->getJson("api/recipes/{$recipe->id}")
            ->assertOk()
            ->assertJsonFragment(['name' => 'Salt']);
    }

    public function test_get_recipe_authenticated_user_increments_view_count(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $user->id, 'category_id' => $this->createCategory()->id]);
        Sanctum::actingAs($user);

        $this->getJson("api/recipes/{$recipe->id}");
        $this->assertDatabaseHas('recipe_views', ['recipe_id' => $recipe->id]);
    }

    public function test_get_recipe_guest_is_unauthorized(): void
    {
        $this->getJson('api/recipes/'.$this->createRecipe()->id)->assertUnauthorized();
    }

    // POST /api/recipes/{recipe}/like

    public function test_post_recipe_like_authenticated_user_can_like(): void
    {
        $fan = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $this->createUser()->id]);
        Sanctum::actingAs($fan);

        $this->postJson("api/recipes/{$recipe->id}/like")
            ->assertCreated()
            ->assertJsonFragment(['liked' => true]);
    }

    public function test_post_recipe_like_duplicate_returns_already_liked(): void
    {
        $fan = $this->createUser();
        $recipe = $this->createRecipe();
        Sanctum::actingAs($fan);

        $this->postJson("api/recipes/{$recipe->id}/like")->assertCreated();
        $this->postJson("api/recipes/{$recipe->id}/like")
            ->assertOk()
            ->assertJsonFragment(['message' => 'Already liked']);
    }

    public function test_post_recipe_like_guest_is_unauthorized(): void
    {
        $this->postJson('api/recipes/'.$this->createRecipe()->id.'/like')->assertUnauthorized();
    }

    // DELETE /api/recipes/{recipe}/like

    public function test_delete_recipe_like_authenticated_user_can_unlike(): void
    {
        $fan = $this->createUser();
        $recipe = $this->createRecipe();
        Sanctum::actingAs($fan);

        $this->postJson("api/recipes/{$recipe->id}/like")->assertCreated();
        $this->deleteJson("api/recipes/{$recipe->id}/like")
            ->assertOk()
            ->assertJsonFragment(['liked' => false]);
    }

    public function test_delete_recipe_like_when_not_liked_is_safe(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->deleteJson('api/recipes/'.$this->createRecipe()->id.'/like')->assertOk();
    }

    public function test_delete_recipe_like_guest_is_unauthorized(): void
    {
        $this->deleteJson('api/recipes/'.$this->createRecipe()->id.'/like')->assertUnauthorized();
    }

    // POST /api/recipes/{recipe}/images

    public function test_post_recipe_image_owner_can_upload(): void
    {
        Storage::fake('public');
        $owner = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $owner->id, 'category_id' => $this->createCategory()->id]);
        Sanctum::actingAs($owner);

        $response = $this->postJson("api/recipes/{$recipe->id}/images", [
            'image' => UploadedFile::fake()->create('recipe.jpg', 100, 'image/jpeg'),
        ]);

        $response->assertCreated()
            ->assertJsonFragment(['message' => 'Image uploaded successfully']);
        $this->assertNotEmpty($response->json('image.image_url'));
    }

    public function test_post_recipe_image_non_owner_is_forbidden(): void
    {
        Storage::fake('public');
        $owner = $this->createUser();
        $intruder = $this->createUser(['email' => 'intruder-recipe@example.com']);
        $recipe = $this->createRecipe(['user_id' => $owner->id, 'category_id' => $this->createCategory()->id]);
        Sanctum::actingAs($intruder);

        $this->postJson("api/recipes/{$recipe->id}/images", [
            'image' => UploadedFile::fake()->create('recipe.jpg', 100, 'image/jpeg'),
        ])->assertForbidden();
    }

    public function test_post_recipe_image_guest_is_unauthorized(): void
    {
        $this->postJson('api/recipes/'.$this->createRecipe()->id.'/images', [
            'image' => UploadedFile::fake()->create('recipe.jpg', 100, 'image/jpeg'),
        ])->assertUnauthorized();
    }
}
