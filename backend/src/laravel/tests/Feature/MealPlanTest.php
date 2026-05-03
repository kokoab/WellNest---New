<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Recipe;
use App\Models\MealPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;
use Illuminate\Support\Facades\Hash;

class MealPlanTest extends TestCase
{
    use RefreshDatabase;

    private function createMealPlan(User $user, Recipe $recipe): MealPlan
    {
        return MealPlan::create([
            'user_id' => $user->id,
            'recipe_id' => $recipe->id,
            'planned_date' => now()->toDateString(),
            'meal_slot' => 'lunch',
        ]);
    }

    public function test_user_can_create_meal_plan(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory(['name' => 'Meals', 'description' => 'Meals desc']);
        $recipe = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Test',
            'instructions' => 'Test',
            'prep_time' => 10
        ]);
        Sanctum::actingAs($user);

        $response = $this->postJson('api/meal-plans', [
            'recipe_id' => $recipe->id,
            'planned_date' => now()->toDateString(),
            'meal_slot' => 'dinner'
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('meal_plans', [
            'user_id' => $user->id,
            'recipe_id' => $recipe->id
        ]);
    }

    public function test_user_can_list_their_meal_plans(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory(['name' => 'Meals', 'description' => 'Meals desc']);
        $recipe = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Test',
            'instructions' => 'Test',
            'prep_time' => 10
        ]);
        $this->createMealPlan($user, $recipe);

        Sanctum::actingAs($user);

        $response = $this->getJson('api/meal-plans?week_start=' . now()->startOfWeek()->toDateString());

        $response->assertOk()
            ->assertJsonPath('data.0.recipe_id', $recipe->id);
    }

    public function test_user_can_delete_meal_plan(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory(['name' => 'Meals', 'description' => 'Meals desc']);
        $recipe = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Test',
            'instructions' => 'Test',
            'prep_time' => 10
        ]);
        $mealPlan = $this->createMealPlan($user, $recipe);

        Sanctum::actingAs($user);

        $response = $this->deleteJson("api/meal-plans/{$mealPlan->id}");

        $response->assertOk();
        $this->assertDatabaseMissing('meal_plans', [
            'id' => $mealPlan->id
        ]);
    }

    public function test_user_cannot_delete_others_meal_plan(): void
    {
        $user = $this->createUser();
        $otherUser = $this->createUser(['email' => 'other@example.com']);
        $category = $this->createCategory(['name' => 'Meals', 'description' => 'Meals desc']);
        $recipe = $this->createRecipe([
            'user_id' => $otherUser->id,
            'category_id' => $category->id,
            'title' => 'Test',
            'instructions' => 'Test',
            'prep_time' => 10
        ]);
        $mealPlan = $this->createMealPlan($otherUser, $recipe);

        Sanctum::actingAs($user);

        $response = $this->deleteJson("api/meal-plans/{$mealPlan->id}");

        $response->assertStatus(403);
    }

    public function test_user_can_export_meal_plans(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->getJson('api/meal-plans/export?week_start=' . now()->startOfWeek()->toDateString());

        $response->assertOk();
    }
}
