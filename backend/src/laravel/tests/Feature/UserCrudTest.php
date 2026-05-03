<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;
use App\Models\User;
use App\Models\Recipe;
use App\Models\Category;
use Laravel\Sanctum\Sanctum;


class UserCrudTest extends TestCase
{
    /**
     * A basic feature test example.
     */

    use RefreshDatabase;


    public function test_admin_can_delete_user_without_data(): void
    {
        $admin = $this->createAdmin();
        $target = $this->createUser();

        Sanctum::actingAs($admin);

        $response = $this->deleteJson("/api/admin/users/{$target->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('users', ['id' => $target->id]);
    }

    public function test_admin_cannot_delete_own_account(): void
    {
        $admin = $this->createAdmin();

        Sanctum::actingAs($admin);

        $response = $this->deleteJson("/api/admin/users/{$admin->id}");

        $response->assertForbidden();
    }

    public function test_admin_cannot_delete_user_with_data(): void
    {
        $admin = $this->createAdmin();
        $target = $this->createUser();

        $recipePost = Recipe::factory()->create([
            'user_id' => $target->id,
        ]);

        Sanctum::actingAs($admin);

        $response = $this->deleteJson("/api/admin/users/{$target->id}");

        $response->assertForbidden();
        $this->assertDatabaseHas('users', ['id' => $target->id]);
        $this->assertDatabaseHas('recipes', ['id' => $recipePost->id]);
    }

    public function test_regular_user_cannot_delete_user(): void
    {
        $user = $this->createUser();
        $target = $this->createUser();

        Sanctum::actingAs($user);

        $response = $this->deleteJson("/api/admin/users/{$target->id}");

        $response->assertForbidden();
        $this->assertDatabaseHas('users', ['id' => $target->id]);
    }

    public function test_unauthenticated_user_cannot_delete_user(): void
    {
        $target = $this->createUser();

        $response = $this->deleteJson("/api/admin/users/{$target->id}");

        $response->assertUnauthorized();
        $this->assertDatabaseHas('users', ['id' => $target->id]);
    }

    public function test_deleting_non_existent_user_returns_404(): void
    {
        $admin = $this->createAdmin();

        Sanctum::actingAs($admin);

        $response = $this->deleteJson("/api/admin/users/999");

        $response->assertNotFound();
    }
}
