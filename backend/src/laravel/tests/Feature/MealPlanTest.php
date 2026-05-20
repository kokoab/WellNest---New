<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Recipe;
use App\Models\MealPlan;
use App\Models\MealPlanDaySkip;
use App\Models\MealPlanMealSkip;
use App\Models\User;
use App\Models\ActivityLog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;
use Illuminate\Support\Facades\Hash;

class MealPlanTest extends TestCase
{
    use RefreshDatabase;

    private function mealPlanFor(User $user, Recipe $recipe, array $attributes = []): MealPlan
    {
        return MealPlan::factory()->create(array_merge([
            'user_id' => $user->id,
            'recipe_id' => $recipe->id,
            'planned_date' => now()->toDateString(),
            'meal_slot' => 'lunch',
        ], $attributes));
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
        $this->assertSame(
            1,
            ActivityLog::where('user_id', $user->id)
                ->where('category', 'meal_planner')
                ->where('action', 'assign_recipe')
                ->count()
        );
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
        $this->mealPlanFor($user, $recipe);

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
        $mealPlan = $this->mealPlanFor($user, $recipe);

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
        $otherUser = $this->createUser();
        $category = $this->createCategory(['name' => 'Meals', 'description' => 'Meals desc']);
        $recipe = $this->createRecipe([
            'user_id' => $otherUser->id,
            'category_id' => $category->id,
            'title' => 'Test',
            'instructions' => 'Test',
            'prep_time' => 10
        ]);
        $mealPlan = $this->mealPlanFor($otherUser, $recipe);

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

    public function test_user_can_plan_breakfast_and_dinner_same_day(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory(['name' => 'Meals', 'description' => 'Meals desc']);
        $recipeA = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Morning',
            'instructions' => 'Test',
            'prep_time' => 5,
        ]);
        $recipeB = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Evening',
            'instructions' => 'Test',
            'prep_time' => 25,
        ]);
        $day = now()->toDateString();

        Sanctum::actingAs($user);

        $this->postJson('api/meal-plans', [
            'recipe_id' => $recipeA->id,
            'planned_date' => $day,
            'meal_slot' => 'breakfast',
        ])->assertCreated();

        $this->postJson('api/meal-plans', [
            'recipe_id' => $recipeB->id,
            'planned_date' => $day,
            'meal_slot' => 'dinner',
        ])->assertCreated();

        $this->assertDatabaseHas('meal_plans', [
            'user_id' => $user->id,
            'recipe_id' => $recipeA->id,
            'meal_slot' => 'breakfast',
        ]);
        $this->assertDatabaseHas('meal_plans', [
            'user_id' => $user->id,
            'recipe_id' => $recipeB->id,
            'meal_slot' => 'dinner',
        ]);
    }

    public function test_meal_plan_week_payload_includes_skipped_dates(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $monday = now()->startOfWeek();
        $wednesday = $monday->copy()->addDays(2);

        $this->postJson('api/meal-plans/day-skip', [
            'planned_date' => $wednesday->toDateString(),
            'did_not_eat' => true,
        ])->assertOk();

        $response = $this->getJson('api/meal-plans?week_start=' . $monday->toDateString());

        $response->assertOk()
            ->assertJsonPath('skipped_dates.0', $wednesday->toDateString());
    }

    public function test_user_can_clear_day_skip(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $monday = now()->startOfWeek();
        $day = $monday->copy()->addDays(1);

        $this->postJson('api/meal-plans/day-skip', [
            'planned_date' => $day->toDateString(),
            'did_not_eat' => true,
        ])->assertOk();

        $this->assertDatabaseHas('meal_plan_day_skips', [
            'user_id' => $user->id,
        ]);

        $this->postJson('api/meal-plans/day-skip', [
            'planned_date' => $day->toDateString(),
            'did_not_eat' => false,
        ])->assertOk();

        $this->assertSame(0, MealPlanDaySkip::where('user_id', $user->id)->count());

        $response = $this->getJson('api/meal-plans?week_start=' . $monday->toDateString());
        $response->assertOk()->assertJsonPath('skipped_dates', []);
    }

    public function test_user_can_mark_one_meal_slot_as_skipped(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $monday = now()->startOfWeek();

        $this->postJson('api/meal-plans/meal-skip', [
            'planned_date' => $monday->toDateString(),
            'meal_slot' => 'breakfast',
            'skipped' => true,
        ])->assertOk();

        $response = $this->getJson('api/meal-plans?week_start=' . $monday->toDateString());

        $response->assertOk()
            ->assertJsonPath('skipped_meals.0.planned_date', $monday->toDateString())
            ->assertJsonPath('skipped_meals.0.meal_slot', 'breakfast');
    }

    public function test_skipping_meal_slot_removes_planned_recipe_for_that_slot(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory(['name' => 'Meals', 'description' => 'Meals desc']);
        $recipe = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Breakfast',
            'instructions' => 'Test',
            'prep_time' => 10,
        ]);
        $day = now()->toDateString();

        Sanctum::actingAs($user);

        $this->postJson('api/meal-plans', [
            'recipe_id' => $recipe->id,
            'planned_date' => $day,
            'meal_slot' => 'breakfast',
        ])->assertCreated();

        $this->postJson('api/meal-plans/meal-skip', [
            'planned_date' => $day,
            'meal_slot' => 'breakfast',
            'skipped' => true,
        ])->assertOk();

        $this->assertSame(0, MealPlan::where('user_id', $user->id)->count());
        $this->assertSame(1, MealPlanMealSkip::where('user_id', $user->id)->count());
    }

    public function test_planning_recipe_clears_skipped_meal_slot(): void
    {
        $user = $this->createUser();
        $category = $this->createCategory(['name' => 'Meals', 'description' => 'Meals desc']);
        $recipe = $this->createRecipe([
            'user_id' => $user->id,
            'category_id' => $category->id,
            'title' => 'Breakfast',
            'instructions' => 'Test',
            'prep_time' => 10,
        ]);
        $day = now()->toDateString();

        Sanctum::actingAs($user);

        $this->postJson('api/meal-plans/meal-skip', [
            'planned_date' => $day,
            'meal_slot' => 'breakfast',
            'skipped' => true,
        ])->assertOk();

        $this->postJson('api/meal-plans', [
            'recipe_id' => $recipe->id,
            'planned_date' => $day,
            'meal_slot' => 'breakfast',
        ])->assertCreated();

        $this->assertSame(1, MealPlan::where('user_id', $user->id)->count());
        $this->assertSame(0, MealPlanMealSkip::where('user_id', $user->id)->count());
    }

    public function test_list_meal_plans_guest_unauthorized(): void
    {
        $this->getJson('api/meal-plans?week_start=' . now()->startOfWeek()->toDateString())
            ->assertUnauthorized();
    }

    public function test_create_meal_plan_guest_unauthorized(): void
    {
        $recipe = $this->createRecipe();

        $this->postJson('api/meal-plans', [
            'recipe_id' => $recipe->id,
            'planned_date' => now()->toDateString(),
            'meal_slot' => 'dinner',
        ])->assertUnauthorized();
    }

    public function test_create_meal_plan_rejects_invalid_meal_slot(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->postJson('api/meal-plans', [
            'recipe_id' => $recipe->id,
            'planned_date' => now()->toDateString(),
            'meal_slot' => 'invalid-slot',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['meal_slot']);
    }

    public function test_day_skip_guest_unauthorized(): void
    {
        $this->postJson('api/meal-plans/day-skip', [
            'planned_date' => now()->toDateString(),
            'did_not_eat' => true,
        ])->assertUnauthorized();
    }

    public function test_meal_skip_guest_unauthorized(): void
    {
        $this->postJson('api/meal-plans/meal-skip', [
            'planned_date' => now()->toDateString(),
            'meal_slot' => 'lunch',
            'skipped' => true,
        ])->assertUnauthorized();
    }

    public function test_delete_meal_plan_guest_unauthorized(): void
    {
        $user = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $user->id]);
        $mealPlan = $this->mealPlanFor($user, $recipe);

        $this->deleteJson("api/meal-plans/{$mealPlan->id}")
            ->assertUnauthorized();
    }

    public function test_export_meal_plans_guest_unauthorized(): void
    {
        $this->getJson('api/meal-plans/export?week_start=' . now()->startOfWeek()->toDateString())
            ->assertUnauthorized();
    }
}
