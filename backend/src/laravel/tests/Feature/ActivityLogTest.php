<?php

namespace Tests\Feature;

use App\Models\ActivityLog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ActivityLogTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_log_meal_planner_activity(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('api/meal-planner/log', [
            'action' => 'assign_recipe',
            'day' => now()->toDateString(),
            'week_start' => now()->startOfWeek()->toDateString(),
            'recipe_title' => 'Healthy Salad'
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('activity_logs', [
            'user_id' => $user->id,
            'category' => 'meal_planner',
            'action' => 'assign_recipe'
        ]);
    }

    public function test_admin_can_view_all_activity_logs(): void
    {
        $admin = $this->createUser(['is_admin' => true, 'email' => 'admin@example.com', 'role' => 'admin']);
        $user = $this->createUser(['email' => 'user@example.com']);
        
        ActivityLog::create([
            'user_id' => $user->id,
            'category' => 'recipe',
            'action' => 'create_recipe',
            'description' => 'User created a recipe',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('api/admin/audit-logs');

        $response->assertOk()
            ->assertJsonFragment(['action' => 'create_recipe']);
    }

    public function test_non_admin_cannot_view_admin_activity_logs(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->getJson('api/admin/audit-logs');

        $response->assertStatus(403);
    }
}
