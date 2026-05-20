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
        
        $this->createActivityLog([
            'user_id' => $user->id,
            'category' => 'recipe',
            'action' => 'create_recipe',
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

    public function test_meal_planner_log_guest_unauthorized(): void
    {
        $this->postJson('api/meal-planner/log', [
            'action' => 'assign_recipe',
            'day' => now()->toDateString(),
        ])->assertUnauthorized();
    }

    public function test_meal_planner_log_validation_rejects_missing_action(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $this->postJson('api/meal-planner/log', [
            'day' => now()->toDateString(),
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['action']);
    }

    public function test_audit_logs_guest_unauthorized(): void
    {
        $this->getJson('api/admin/audit-logs')->assertUnauthorized();
    }

    public function test_admin_can_export_audit_logs_csv(): void
    {
        $admin = $this->createAdmin();
        $this->createActivityLog([
            'category' => 'auth',
            'action' => 'login',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->get('api/admin/audit-logs/export');

        $response->assertOk();
        $this->assertStringContainsString('text/csv', (string) $response->headers->get('Content-Type'));
    }

    public function test_audit_logs_export_non_admin_forbidden(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $this->getJson('api/admin/audit-logs/export')->assertForbidden();
    }

    public function test_audit_logs_export_guest_unauthorized(): void
    {
        $this->getJson('api/admin/audit-logs/export')->assertUnauthorized();
    }
}
