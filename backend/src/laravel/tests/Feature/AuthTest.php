<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;
use Laravel\Sanctum\Sanctum;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_successfully_creates_user_and_returns_token(): void
    {
        $response = $this->postJson('api/register', [
            'first_name' => 'Jane',
            'last_name' => 'Doe',
            'email' => 'jane@example.com',
            'password' => 'password123',
            'accepted_terms' => true,
        ]);

        $response->assertCreated()
            ->assertJsonStructure([
                'message',
                'user' => ['id', 'first_name', 'last_name', 'email'],
                'token',
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'jane@example.com',
            'first_name' => 'Jane',
            'last_name' => 'Doe',
        ]);
    }

    public function test_register_fails_when_email_is_duplicate(): void
    {
        $this->createUser(['email' => 'duplicate@example.com']);

        $response = $this->postJson('api/register', [
            'first_name' => 'Jane',
            'last_name' => 'Doe',
            'email' => 'duplicate@example.com',
            'password' => 'password123',
            'accepted_terms' => true,
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }

    public function test_register_fails_when_terms_not_accepted(): void
    {
        $response = $this->postJson('api/register', [
            'first_name' => 'Jane',
            'last_name' => 'Doe',
            'email' => 'no-terms@example.com',
            'password' => 'password123',
            'accepted_terms' => false,
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['accepted_terms']);
    }

    public function test_login_returns_token_for_valid_credentials(): void
    {
        $this->createUser([
            'email' => 'login@example.com',
            'password' => 'password123',
        ]);

        $response = $this->postJson('api/login', [
            'email' => 'login@example.com',
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Login successful'])
            ->assertJsonStructure(['token', 'user']);
    }

    public function test_login_fails_for_invalid_credentials(): void
    {
        $this->createUser([
            'email' => 'wrongpass@example.com',
            'password' => 'password123',
        ]);

        $response = $this->postJson('api/login', [
            'email' => 'wrongpass@example.com',
            'password' => 'wrong-password',
        ]);

        $response->assertStatus(401)
            ->assertJsonFragment(['message' => 'Invalid credentials']);
    }

    public function test_login_fails_for_suspended_user(): void
    {
        $this->createUser([
            'email' => 'suspended@example.com',
            'password' => 'password123',
            'account_status' => 'suspended',
        ]);

        $response = $this->postJson('api/login', [
            'email' => 'suspended@example.com',
            'password' => 'password123',
        ]);

        $response->assertStatus(403)
            ->assertJsonFragment(['message' => 'Account is suspended']);
    }

    public function test_user_can_logout(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('api/logout');

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Logged out successfully']);
    }

    public function test_user_can_update_profile(): void
    {
        $user = $this->createUser([
            'email' => 'profile@example.com',
            'first_name' => 'Old',
            'last_name' => 'Name',
        ]);
        Sanctum::actingAs($user);

        $response = $this->patchJson('api/user', [
            'first_name' => 'New',
            'last_name' => 'Person',
            'email' => 'new-profile@example.com',
            'password' => 'newpassword123',
        ]);

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Profile updated']);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'first_name' => 'New',
            'last_name' => 'Person',
            'email' => 'new-profile@example.com',
        ]);
    }

    public function test_user_can_upload_profile_photo(): void
    {
        Storage::fake('public');

        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('api/user/profile-photo', [
            'image' => UploadedFile::fake()->create('avatar.jpg', 100, 'image/jpeg'),
        ]);

        $response->assertCreated()
            ->assertJsonFragment(['message' => 'Profile photo uploaded successfully']);

        $this->assertNotEmpty($response->json('profile_photo_url'));
    }

    public function test_user_can_deactivate_self(): void
    {
        $user = $this->createUser();
        Sanctum::actingAs($user);

        $response = $this->patchJson('api/me/deactivate', [
            'reason' => 'No longer needed',
        ]);

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Account deactivated successfully.']);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'account_status' => 'deactivated',
        ]);
    }
}

