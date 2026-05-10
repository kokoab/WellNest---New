<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Post;
use App\Models\Recipe;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminOperationsTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_register_a_new_admin(): void
    {
        $admin = $this->createAdmin();
        Sanctum::actingAs($admin);

        $response = $this->postJson('api/register-admin', [
            'first_name' => 'New',
            'last_name' => 'Admin',
            'email' => 'new-admin@gmail.com',
            'password' => 'password123',
        ]);

        $response->assertCreated()
            ->assertJsonFragment(['message' => 'Admin created successfully']);

        $this->assertDatabaseHas('users', [
            'email' => 'new-admin@gmail.com',
            'role' => 'admin',
            'is_admin' => true,
        ]);
    }

    public function test_admin_login_returns_token(): void
    {
        $admin = $this->createAdmin([
            'email' => 'admin-login@example.com',
            'password' => 'password123',
        ]);

        $response = $this->postJson('api/login-admin', [
            'email' => 'admin-login@example.com',
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Login successful'])
            ->assertJsonStructure(['token', 'admin']);
    }

    public function test_admin_can_logout(): void
    {
        $admin = $this->createAdmin();
        Sanctum::actingAs($admin);

        $response = $this->postJson('api/logout-admin');

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Logged out successfully']);
    }

    public function test_admin_can_list_users(): void
    {
        $admin = $this->createAdmin();
        $this->createUser(['email' => 'user-one@example.com']);
        $this->createUser(['email' => 'user-two@example.com']);

        Sanctum::actingAs($admin);

        $response = $this->getJson('api/admin/users');

        $response->assertOk()
            ->assertJsonCount(3);
    }

    public function test_admin_can_update_user_status(): void
    {
        $admin = $this->createAdmin();
        $user = $this->createUser(['email' => 'status-user@example.com']);

        Sanctum::actingAs($admin);

        $response = $this->patchJson("api/admin/users/{$user->id}/status", [
            'account_status' => 'suspended',
        ]);

        $response->assertOk()
            ->assertJsonPath('account_status', 'suspended');

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'account_status' => 'suspended',
        ]);
    }

    public function test_admin_dashboard_overview_returns_counts(): void
    {
        $admin = $this->createAdmin();
        $this->createUser();
        $this->createPost(['user_id' => $this->createUser()->id]);
        Conversation::create([
            'user1_id' => $this->createUser()->id,
            'user2_id' => $this->createUser(['email' => 'other@example.com'])->id,
        ]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('api/admin/stats/overview');

        $response->assertOk()
            ->assertJsonStructure([
                'total_users',
                'total_posts',
                'total_conversations',
                'active_users',
                'inactive_users',
            ]);
    }

    public function test_admin_dashboard_user_growth_returns_data(): void
    {
        $admin = $this->createAdmin();
        $this->createUser(['email' => 'growth@example.com']);

        Sanctum::actingAs($admin);

        $response = $this->getJson('api/admin/stats/user-growth?range=monthly');

        $response->assertOk()
            ->assertJsonPath('range', 'monthly')
            ->assertJsonStructure(['data', 'range']);
    }

    public function test_admin_dashboard_post_frequency_returns_data(): void
    {
        $admin = $this->createAdmin();
        $owner = $this->createUser();
        $this->createPost(['user_id' => $owner->id]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('api/admin/stats/post-frequency?range=monthly');

        $response->assertOk()
            ->assertJsonPath('range', 'monthly')
            ->assertJsonStructure(['data', 'range']);
    }

    public function test_admin_dashboard_chatbot_interactions_returns_data(): void
    {
        $admin = $this->createAdmin();
        $userOne = $this->createUser(['email' => 'chat-1@example.com']);
        $userTwo = $this->createUser(['email' => 'chat-2@example.com']);
        Conversation::create([
            'user1_id' => $userOne->id,
            'user2_id' => $userTwo->id,
        ]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('api/admin/stats/chatbot-interactions?range=monthly');

        $response->assertOk()
            ->assertJsonPath('range', 'monthly')
            ->assertJsonStructure(['data', 'range']);
    }

    public function test_admin_can_delete_recipe_owned_by_another_user(): void
    {
        $admin = $this->createAdmin();
        $owner = $this->createUser();
        $recipe = $this->createRecipe(['user_id' => $owner->id]);

        Sanctum::actingAs($admin);

        $response = $this->deleteJson("api/recipes/{$recipe->id}");

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Recipe deleted successfully']);

        $this->assertDatabaseMissing('recipes', ['id' => $recipe->id]);
    }

    public function test_regular_user_cannot_delete_another_users_recipe(): void
    {
        $owner = $this->createUser();
        $other = $this->createUser(['email' => 'other-recipe@example.com']);
        $recipe = $this->createRecipe(['user_id' => $owner->id]);

        Sanctum::actingAs($other);

        $response = $this->deleteJson("api/recipes/{$recipe->id}");

        $response->assertForbidden();
        $this->assertDatabaseHas('recipes', ['id' => $recipe->id]);
    }
}
