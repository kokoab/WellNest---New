<?php

namespace Tests\Feature;

use App\Models\Post;
use App\Models\Recipe;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminModerationTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_list_pending_reports(): void
    {
        $admin = $this->createAdmin();
        $reporter = $this->createUser();
        $target = $this->createUser();
        $recipe = $this->createRecipe([
            'user_id' => $target->id,
            'category_id' => $this->createCategory()->id,
        ]);

        $this->createReport([
            'user_id' => $reporter->id,
            'reportable_id' => $recipe->id,
            'reportable_type' => Recipe::class,
            'reason' => fake()->words(3, true),
            'details' => fake()->sentence(),
            'status' => 'pending',
        ]);
        $this->createReport([
            'user_id' => $reporter->id,
            'reportable_id' => $target->id,
            'reportable_type' => User::class,
            'reason' => fake()->words(3, true),
            'details' => fake()->sentence(),
            'status' => 'approved',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('api/admin/reports');

        $response->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.status', 'pending');
    }

    public function test_admin_can_approve_a_report(): void
    {
        $admin = $this->createAdmin();
        $report = $this->pendingRecipeReport();

        Sanctum::actingAs($admin);

        $response = $this->patchJson("api/admin/reports/{$report->id}/approve");

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Report approved (dismissed).']);

        $this->assertDatabaseHas('reports', [
            'id' => $report->id,
            'status' => 'approved',
        ]);
    }

    public function test_admin_cannot_approve_an_already_processed_report(): void
    {
        $admin = $this->createAdmin();
        $report = $this->pendingRecipeReport();

        Sanctum::actingAs($admin);

        $this->patchJson("api/admin/reports/{$report->id}/approve")->assertOk();

        $response = $this->patchJson("api/admin/reports/{$report->id}/approve");

        $response->assertStatus(400)
            ->assertJsonFragment(['message' => 'Report already processed']);
    }

    public function test_admin_can_dismiss_a_report(): void
    {
        $admin = $this->createAdmin();
        $report = $this->pendingRecipeReport();

        Sanctum::actingAs($admin);

        $response = $this->patchJson("api/admin/reports/{$report->id}/dismiss");

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Report dismissed.']);

        $this->assertDatabaseHas('reports', [
            'id' => $report->id,
            'status' => 'dismissed',
        ]);
    }

    public function test_admin_can_remove_reported_recipe(): void
    {
        $admin = $this->createAdmin();
        $report = $this->pendingRecipeReport();
        $recipe = Recipe::findOrFail($report->reportable_id);

        Sanctum::actingAs($admin);

        $response = $this->patchJson("api/admin/reports/{$report->id}/remove-content");

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Content removed.']);

        $this->assertDatabaseMissing('recipes', ['id' => $recipe->id]);
        $this->assertDatabaseHas('reports', [
            'id' => $report->id,
            'status' => 'removed',
        ]);
    }

    public function test_admin_can_suspend_reported_user(): void
    {
        $admin = $this->createAdmin();
        $reporter = $this->createUser();
        $target = $this->createUser();

        $report = $this->createReport([
            'user_id' => $reporter->id,
            'reportable_id' => $target->id,
            'reportable_type' => User::class,
            'reason' => fake()->words(3, true),
            'details' => fake()->sentence(),
            'status' => 'pending',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->patchJson("api/admin/reports/{$report->id}/suspend-user");

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Account suspended.']);

        $this->assertDatabaseHas('users', [
            'id' => $target->id,
            'account_status' => 'suspended',
        ]);
        $this->assertDatabaseHas('reports', [
            'id' => $report->id,
            'status' => 'suspended',
        ]);
    }

    public function test_admin_can_unban_reported_user(): void
    {
        $admin = $this->createAdmin();
        $reporter = $this->createUser();
        $target = $this->createUser(['account_status' => 'suspended']);

        $report = $this->createReport([
            'user_id' => $reporter->id,
            'reportable_id' => $target->id,
            'reportable_type' => User::class,
            'reason' => fake()->words(3, true),
            'details' => fake()->sentence(),
            'status' => 'suspended',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->patchJson("api/admin/reports/{$report->id}/unban-user");

        $response->assertOk()
            ->assertJsonFragment(['message' => 'User unbanned']);

        $this->assertDatabaseHas('users', [
            'id' => $target->id,
            'account_status' => 'active',
        ]);
        $this->assertDatabaseHas('reports', [
            'id' => $report->id,
            'status' => 'unbanned',
        ]);
    }

    public function test_admin_can_delete_all_pending_reports(): void
    {
        $admin = $this->createAdmin();
        $this->pendingRecipeReport();
        $this->pendingPostReport();
        $this->createReport([
            'user_id' => $this->createUser()->id,
            'reportable_id' => $this->createUser()->id,
            'reportable_type' => User::class,
            'reason' => fake()->words(3, true),
            'details' => fake()->sentence(),
            'status' => 'approved',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->deleteJson('api/admin/reports');

        $response->assertOk()
            ->assertJsonFragment(['message' => 'All pending reports deleted.']);

        $this->assertDatabaseMissing('reports', ['status' => 'pending']);
    }

    private function pendingRecipeReport(): Report
    {
        $reporter = $this->createUser();
        $owner = $this->createUser();
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $this->createCategory()->id,
        ]);

        return $this->createReport([
            'user_id' => $reporter->id,
            'reportable_id' => $recipe->id,
            'reportable_type' => Recipe::class,
            'status' => 'pending',
        ]);
    }

    private function pendingPostReport(): Report
    {
        $reporter = $this->createUser();
        $owner = $this->createUser();
        $post = $this->createPost([
            'user_id' => $owner->id,
        ]);

        return $this->createReport([
            'user_id' => $reporter->id,
            'reportable_id' => $post->id,
            'reportable_type' => Post::class,
            'status' => 'pending',
        ]);
    }

    public function test_admin_reports_list_non_admin_forbidden(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->getJson('api/admin/reports')->assertForbidden();
    }

    public function test_admin_reports_list_guest_unauthorized(): void
    {
        $this->getJson('api/admin/reports')->assertUnauthorized();
    }

    public function test_admin_approve_report_non_admin_forbidden(): void
    {
        $report = $this->pendingRecipeReport();
        Sanctum::actingAs($this->createUser());

        $this->patchJson("api/admin/reports/{$report->id}/approve")->assertForbidden();
    }

    public function test_admin_approve_report_guest_unauthorized(): void
    {
        $report = $this->pendingRecipeReport();

        $this->patchJson("api/admin/reports/{$report->id}/approve")->assertUnauthorized();
    }

    public function test_admin_dismiss_report_non_admin_forbidden(): void
    {
        $report = $this->pendingRecipeReport();
        Sanctum::actingAs($this->createUser());

        $this->patchJson("api/admin/reports/{$report->id}/dismiss")->assertForbidden();
    }

    public function test_admin_dismiss_report_guest_unauthorized(): void
    {
        $report = $this->pendingRecipeReport();

        $this->patchJson("api/admin/reports/{$report->id}/dismiss")->assertUnauthorized();
    }

    public function test_admin_remove_content_non_admin_forbidden(): void
    {
        $report = $this->pendingRecipeReport();
        Sanctum::actingAs($this->createUser());

        $this->patchJson("api/admin/reports/{$report->id}/remove-content")->assertForbidden();
    }

    public function test_admin_remove_content_guest_unauthorized(): void
    {
        $report = $this->pendingRecipeReport();

        $this->patchJson("api/admin/reports/{$report->id}/remove-content")->assertUnauthorized();
    }

    public function test_admin_suspend_user_non_admin_forbidden(): void
    {
        $report = $this->pendingRecipeReport();
        Sanctum::actingAs($this->createUser());

        $this->patchJson("api/admin/reports/{$report->id}/suspend-user")->assertForbidden();
    }

    public function test_admin_suspend_user_guest_unauthorized(): void
    {
        $report = $this->pendingRecipeReport();

        $this->patchJson("api/admin/reports/{$report->id}/suspend-user")->assertUnauthorized();
    }

    public function test_admin_unban_user_non_admin_forbidden(): void
    {
        $admin = $this->createAdmin();
        $reporter = $this->createUser();
        $target = $this->createUser(['account_status' => 'suspended']);
        $report = $this->createReport([
            'user_id' => $reporter->id,
            'reportable_id' => $target->id,
            'reportable_type' => User::class,
            'status' => 'suspended',
        ]);

        Sanctum::actingAs($this->createUser());

        $this->patchJson("api/admin/reports/{$report->id}/unban-user")->assertForbidden();
    }

    public function test_admin_unban_user_guest_unauthorized(): void
    {
        $reporter = $this->createUser();
        $target = $this->createUser(['account_status' => 'suspended']);
        $report = $this->createReport([
            'user_id' => $reporter->id,
            'reportable_id' => $target->id,
            'reportable_type' => User::class,
            'status' => 'suspended',
        ]);

        $this->patchJson("api/admin/reports/{$report->id}/unban-user")->assertUnauthorized();
    }

    public function test_admin_delete_reports_non_admin_forbidden(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->deleteJson('api/admin/reports')->assertForbidden();
    }

    public function test_admin_delete_reports_guest_unauthorized(): void
    {
        $this->deleteJson('api/admin/reports')->assertUnauthorized();
    }

    public function test_admin_recipe_rankings_returns_data(): void
    {
        $admin = $this->createAdmin();
        $this->createRecipe();
        Sanctum::actingAs($admin);

        $this->getJson('api/admin/recipes/rankings')
            ->assertOk()
            ->assertJsonStructure(['data']);
    }

    public function test_admin_recipe_rankings_non_admin_forbidden(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->getJson('api/admin/recipes/rankings')->assertForbidden();
    }

    public function test_admin_recipe_rankings_guest_unauthorized(): void
    {
        $this->getJson('api/admin/recipes/rankings')->assertUnauthorized();
    }
}
