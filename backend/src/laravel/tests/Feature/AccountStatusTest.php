<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Laravel\Sanctum\Sanctum;

class AccountStatusTest extends TestCase
{
    use RefreshDatabase;

    public function test_active_user_is_authorized_to_the_system(): void
    {
        $user = User::factory()->create(['account_status' => 'active']);


        Sanctum::actingAs($user);
        $response = $this->getJson("api/user");

        $response->assertOk();
    }

    public function test_suspended_user_is_blocked_by_middleware()
    {
        $user = User::factory()->create(['account_status' => 'suspended']);

        Sanctum::actingAs($user);
        $response = $this->getJson('api/user');

        // Based on the 'check.account.status' middleware implementation
        $response->assertForbidden();
    }

    public function test_deactivated_user_is_blocked_by_middleware()
    {
        $user = User::factory()->create(['account_status' => 'deactivated']);

        Sanctum::actingAs($user);
        $response = $this->getJson('api/user');

        $response->assertStatus(403)
                 ->assertJsonPath('status', 'deactivated');
    }

    public function test_admin_can_suspend_user()
    {
        $admin = User::factory()->create(['role' => 'admin', 'is_admin' => true]);
        $user = User::factory()->create(['account_status' => 'active']);

        Sanctum::actingAs($admin);
        $response = $this->patchJson("api/admin/users/{$user->id}/status", [
            'account_status' => 'suspended'
        ]);

        $response->assertStatus(200);
        $this->assertEquals('suspended', $user->fresh()->account_status);
    }

    public function test_user_can_deactivate_self()
    {
        $user = User::factory()->create(['account_status' => 'active']);

        Sanctum::actingAs($user);
        $response = $this->patchJson('api/me/deactivate');

        $response->assertStatus(200);
        $this->assertEquals('deactivated', $user->fresh()->account_status);
    }
}
