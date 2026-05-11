<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Post;
use App\Models\Recipe;
use App\Models\Report;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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

    public function test_admin_dashboard_user_growth_returns_bucketed_series(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-05-11 15:00:00', 'UTC'));
        try {
            $admin = $this->createAdmin();
            $user = $this->createUser(['email' => 'growth@example.com']);
            DB::table('users')->where('id', $user->id)->update([
                'created_at' => '2026-05-10 12:00:00',
                'updated_at' => '2026-05-10 12:00:00',
            ]);

            Sanctum::actingAs($admin);

            $response = $this->getJson('api/admin/stats/user-growth?range=all');

            $response->assertOk()
                ->assertJsonPath('range', 'all')
                ->assertJsonPath('bucket_count', 6);

            $rows = $response->json('data');
            $this->assertCount(6, $rows);
            $this->assertGreaterThanOrEqual(1, collect($rows)->sum('count'));
        } finally {
            Carbon::setTestNow();
        }
    }

    public function test_admin_dashboard_post_frequency_returns_bucketed_series(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-05-11 15:00:00', 'UTC'));
        try {
            $admin = $this->createAdmin();
            $owner = $this->createUser();
            $post = $this->createPost(['user_id' => $owner->id]);
            DB::table('posts')->where('id', $post->id)->update([
                'created_at' => '2026-05-10 10:00:00',
                'updated_at' => '2026-05-10 10:00:00',
            ]);

            Sanctum::actingAs($admin);

            $response = $this->getJson('api/admin/stats/post-frequency?range=monthly');

            $response->assertOk()
                ->assertJsonPath('range', 'monthly')
                ->assertJsonPath('bucket_count', 6);

            $rows = $response->json('data');
            $this->assertCount(6, $rows);
            $this->assertSame('December 2025', $rows[0]['label']);
            $this->assertSame('May 2026', $rows[5]['label']);
        } finally {
            Carbon::setTestNow();
        }
    }

    public function test_admin_dashboard_chatbot_interactions_returns_bucketed_series(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-05-11 15:00:00', 'UTC'));
        try {
            $admin = $this->createAdmin();
            $userOne = $this->createUser(['email' => 'chat-1@example.com']);
            $userTwo = $this->createUser(['email' => 'chat-2@example.com']);
            $conversation = Conversation::create([
                'user1_id' => $userOne->id,
                'user2_id' => $userTwo->id,
            ]);
            DB::table('conversations')->where('id', $conversation->id)->update([
                'created_at' => '2026-05-10 08:00:00',
                'updated_at' => '2026-05-10 08:00:00',
            ]);

            Sanctum::actingAs($admin);

            $response = $this->getJson('api/admin/stats/chatbot-interactions?range=monthly');

            $response->assertOk()
                ->assertJsonPath('range', 'monthly')
                ->assertJsonPath('bucket_count', 6);

            $rows = $response->json('data');
            $this->assertCount(6, $rows);
            foreach ($rows as $row) {
                $this->assertArrayHasKey('label', $row);
            }
        } finally {
            Carbon::setTestNow();
        }
    }

    public function test_admin_dashboard_user_growth_weekly_returns_seven_daily_buckets(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-05-11 15:00:00', 'UTC'));
        try {
            $admin = $this->createAdmin();
            Sanctum::actingAs($admin);

            $response = $this->getJson('api/admin/stats/user-growth?range=weekly');

            $response->assertOk()
                ->assertJsonPath('range', 'weekly')
                ->assertJsonPath('bucket_count', 7);

            $rows = $response->json('data');
            $this->assertCount(7, $rows);
            $this->assertSame('2026-05-05', $rows[0]['date']);
            $this->assertSame('2026-05-11', $rows[6]['date']);
            $this->assertArrayHasKey('label', $rows[0]);
            $this->assertStringContainsString('May', $rows[6]['label']);
        } finally {
            Carbon::setTestNow();
        }
    }

    public function test_admin_dashboard_user_growth_yearly_returns_twelve_calendar_months(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-05-11 15:00:00', 'UTC'));
        try {
            $admin = $this->createAdmin();
            Sanctum::actingAs($admin);

            $response = $this->getJson('api/admin/stats/user-growth?range=yearly');

            $response->assertOk()
                ->assertJsonPath('range', 'yearly')
                ->assertJsonPath('bucket_count', 12);

            $rows = $response->json('data');
            $this->assertCount(12, $rows);
            $this->assertSame('Jun \'25', $rows[0]['label']);
            $this->assertSame('May \'26', $rows[11]['label']);
        } finally {
            Carbon::setTestNow();
        }
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
