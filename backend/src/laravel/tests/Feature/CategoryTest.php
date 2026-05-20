<?php

namespace Tests\Feature;

use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CategoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_get_categories_authenticated_user_can_list_sorted_by_name(): void
    {
        $this->createCategory([
            'name' => 'Zucchini',
            'description' => 'Late alphabet',
        ]);
        $this->createCategory([
            'name' => 'Apple',
            'description' => 'First alphabet',
        ]);

        Sanctum::actingAs($this->createUser());

        $response = $this->getJson('/api/categories');

        $response->assertOk()
            ->assertJsonPath('0.name', 'Apple')
            ->assertJsonPath('1.name', 'Zucchini');
    }

    public function test_get_categories_guest_is_unauthorized(): void
    {
        $this->getJson('/api/categories')->assertUnauthorized();
    }

    public function test_get_category_authenticated_user_can_show(): void
    {
        $category = $this->createCategory([
            'name' => 'Breakfast',
            'description' => 'Morning meals',
        ]);

        Sanctum::actingAs($this->createUser());

        $response = $this->getJson("/api/categories/{$category->id}");

        $response->assertOk()
            ->assertJsonFragment([
                'id' => $category->id,
                'name' => 'Breakfast',
                'description' => 'Morning meals',
            ]);
    }

    public function test_get_category_guest_is_unauthorized(): void
    {
        $category = $this->createCategory();

        $this->getJson("/api/categories/{$category->id}")->assertUnauthorized();
    }

    public function test_get_category_authenticated_user_gets_404_for_missing(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->getJson('/api/categories/999999')->assertNotFound();
    }

    public function test_admin_can_create_category(): void
    {
        $admin = $this->createAdmin();
        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/categories', [
            'name' => 'Lunch',
            'description' => 'Midday meals',
        ]);

        $response->assertCreated()
            ->assertJsonFragment([
                'name' => 'Lunch',
                'description' => 'Midday meals',
            ]);

        $this->assertDatabaseHas('categories', [
            'name' => 'Lunch',
            'description' => 'Midday meals',
        ]);
    }

    public function test_category_creation_requires_valid_input(): void
    {
        $admin = $this->createAdmin();
        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/categories', [
            'name' => '',
            'description' => '',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['name', 'description']);
    }

    public function test_category_creation_rejects_duplicate_name(): void
    {
        $admin = $this->createAdmin();
        $this->createCategory([
            'name' => 'Dinner',
            'description' => 'Evening meals',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/categories', [
            'name' => 'Dinner',
            'description' => 'Another description',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['name']);
    }

    public function test_guest_cannot_create_category(): void
    {
        $response = $this->postJson('/api/categories', [
            'name' => 'Dinner',
            'description' => 'Evening meals',
        ]);

        $response->assertUnauthorized();
    }

    public function test_regular_user_is_forbidden_from_creating_category(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/categories', [
            'name' => 'Dinner',
            'description' => 'Evening meals',
        ]);

        $response->assertForbidden();
    }

    public function test_admin_can_update_category(): void
    {
        $admin = $this->createAdmin();
        $category = $this->createCategory([
            'name' => 'Snacks',
            'description' => 'Small bites',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->putJson("/api/categories/{$category->id}", [
            'name' => 'Healthy Snacks',
            'description' => 'Better small bites',
        ]);

        $response->assertOk()
            ->assertJsonFragment([
                'id' => $category->id,
                'name' => 'Healthy Snacks',
                'description' => 'Better small bites',
            ]);

        $this->assertDatabaseHas('categories', [
            'id' => $category->id,
            'name' => 'Healthy Snacks',
            'description' => 'Better small bites',
        ]);
    }

    public function test_category_update_requires_valid_input(): void
    {
        $admin = $this->createAdmin();
        $category = $this->createCategory([
            'name' => 'Drinks',
            'description' => 'All drinks',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->putJson("/api/categories/{$category->id}", [
            'name' => '',
            'description' => '',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['name', 'description']);
    }

    public function test_category_update_rejects_duplicate_name(): void
    {
        $admin = $this->createAdmin();
        $category = $this->createCategory([
            'name' => 'Appetizers',
            'description' => 'Starter dishes',
        ]);
        $this->createCategory([
            'name' => 'Main Course',
            'description' => 'Primary dishes',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->putJson("/api/categories/{$category->id}", [
            'name' => 'Main Course',
            'description' => 'Updated starter dishes',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['name']);
    }

    public function test_guest_cannot_update_category(): void
    {
        $category = $this->createCategory([
            'name' => 'Dessert',
            'description' => 'Sweet dishes',
        ]);

        $response = $this->putJson("/api/categories/{$category->id}", [
            'name' => 'Desserts',
            'description' => 'Sweet dishes',
        ]);

        $response->assertUnauthorized();
    }

    public function test_regular_user_is_forbidden_from_updating_category(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory([
            'name' => 'Soup',
            'description' => 'Warm meals',
        ]);

        Sanctum::actingAs($user);

        $response = $this->putJson("/api/categories/{$category->id}", [
            'name' => 'Soups',
            'description' => 'Warm meals',
        ]);

        $response->assertForbidden();
    }

    public function test_admin_can_delete_category(): void
    {
        $admin = $this->createAdmin();
        $category = $this->createCategory([
            'name' => 'Frozen',
            'description' => 'Cold food',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->deleteJson("/api/categories/{$category->id}");

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Category deleted successfully']);

        $this->assertDatabaseMissing('categories', [
            'id' => $category->id,
        ]);
    }

    public function test_guest_cannot_delete_category(): void
    {
        $category = $this->createCategory([
            'name' => 'Frozen',
            'description' => 'Cold food',
        ]);

        $response = $this->deleteJson("/api/categories/{$category->id}");

        $response->assertUnauthorized();
    }

    public function test_regular_user_is_forbidden_from_deleting_category(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory([
            'name' => 'Frozen',
            'description' => 'Cold food',
        ]);

        Sanctum::actingAs($user);

        $response = $this->deleteJson("/api/categories/{$category->id}");

        $response->assertForbidden();
    }

    public function test_find_or_create_for_recipe_matches_existing_category_case_insensitively(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $existing = $this->createCategory([
            'name' => 'Vegan',
            'description' => 'Plant-based',
        ]);

        $response = $this->postJson('/api/categories/for-recipe', [
            'name' => 'vegan',
            'description' => 'User-created recipe category.',
        ]);

        $response->assertOk()
            ->assertJsonPath('id', $existing->id)
            ->assertJsonPath('name', 'Vegan');
    }

    public function test_for_recipe_guest_unauthorized(): void
    {
        $this->postJson('/api/categories/for-recipe', [
            'name' => fake()->word(),
            'description' => fake()->sentence(),
        ])->assertUnauthorized();
    }

    public function test_for_recipe_creates_new_category_when_no_match(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $name = ucfirst(fake()->unique()->word());

        $response = $this->postJson('/api/categories/for-recipe', [
            'name' => $name,
            'description' => fake()->sentence(),
        ]);

        $response->assertCreated()
            ->assertJsonPath('name', $name);

        $this->assertDatabaseHas('categories', ['name' => $name]);
    }

    public function test_regular_user_can_use_for_recipe_endpoint(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $name = ucfirst(fake()->unique()->word());

        $this->postJson('/api/categories/for-recipe', [
            'name' => $name,
            'description' => fake()->sentence(),
        ])->assertCreated();
    }
}
