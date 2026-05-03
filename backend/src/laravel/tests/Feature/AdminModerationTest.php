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
        $reporter = $this->createUser(['email' => 'reporter@example.com']);
        $target = $this->createUser(['email' => 'target@example.com']);
        $recipe = $this->createRecipe([
            'user_id' => $target->id,
            'category_id' => $this->createCategory()->id,
        ]);

        Report::create([
            'user_id' => $reporter->id,
            'reportable_id' => $recipe->id,
            'reportable_type' => Recipe::class,
            'reason' => 'Spam',
            'details' => 'Looks suspicious',
            'status' => 'pending',
        ]);
        Report::create([
            'user_id' => $reporter->id,
            'reportable_id' => $target->id,
            'reportable_type' => User::class,
            'reason' => 'Abuse',
            'details' => 'Bad behavior',
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
        $reporter = $this->createUser(['email' => 'reporter2@example.com']);
        $target = $this->createUser(['email' => 'reported-user@example.com']);

        $report = Report::create([
            'user_id' => $reporter->id,
            'reportable_id' => $target->id,
            'reportable_type' => User::class,
            'reason' => 'Abuse',
            'details' => 'Needs review',
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
        $reporter = $this->createUser(['email' => 'reporter3@example.com']);
        $target = $this->createUser(['email' => 'banned-user@example.com', 'account_status' => 'suspended']);

        $report = Report::create([
            'user_id' => $reporter->id,
            'reportable_id' => $target->id,
            'reportable_type' => User::class,
            'reason' => 'Abuse',
            'details' => 'Previously suspended',
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
        Report::create([
            'user_id' => $this->createUser(['email' => 'done@example.com'])->id,
            'reportable_id' => $this->createUser(['email' => 'done-target@example.com'])->id,
            'reportable_type' => User::class,
            'reason' => 'Spam',
            'details' => 'Already processed',
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
        $reporter = $this->createUser(['email' => fake()->unique()->safeEmail()]);
        $owner = $this->createUser(['email' => fake()->unique()->safeEmail()]);
        $recipe = $this->createRecipe([
            'user_id' => $owner->id,
            'category_id' => $this->createCategory()->id,
        ]);

        return Report::create([
            'user_id' => $reporter->id,
            'reportable_id' => $recipe->id,
            'reportable_type' => Recipe::class,
            'reason' => 'Spam',
            'details' => 'Needs attention',
            'status' => 'pending',
        ]);
    }

    private function pendingPostReport(): Report
    {
        $reporter = $this->createUser(['email' => fake()->unique()->safeEmail()]);
        $owner = $this->createUser(['email' => fake()->unique()->safeEmail()]);
        $post = $this->createPost([
            'user_id' => $owner->id,
        ]);

        return Report::create([
            'user_id' => $reporter->id,
            'reportable_id' => $post->id,
            'reportable_type' => Post::class,
            'reason' => 'Spam',
            'details' => 'Needs attention',
            'status' => 'pending',
        ]);
    }
}
