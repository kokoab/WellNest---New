<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExampleTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_health_endpoint_is_available(): void
    {
        $response = $this->getJson('/api/hello');

        $response
            ->assertOk()
            ->assertJson([
                'message' => 'hello',
            ]);
    }

    public function test_protected_user_endpoint_requires_authentication(): void
    {
        $response = $this->getJson('/api/user');

        $response->assertUnauthorized();
    }

    public function test_authenticated_user_endpoint_returns_current_user_data(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test-token')->plainTextToken;

        $response = $this
            ->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/user');

        $response
            ->assertOk()
            ->assertJsonPath('email', $user->email);
    }
}
