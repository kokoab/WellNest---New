<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use ReflectionClass;
use Tests\TestCase;

class UserProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_fetch_current_profile(): void
    {
        $user = $this->createUser([
            'first_name' => 'Profile',
            'last_name' => 'User',
            'email' => 'profile-user@example.com',
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('api/user');

        $response->assertOk()
            ->assertJsonPath('email', 'profile-user@example.com')
            ->assertJsonPath('first_name', 'Profile')
            ->assertJsonPath('last_name', 'User');
    }

    public function test_user_search_excludes_self_and_returns_matches(): void
    {
        $this->resetAssistantCache();

        $user = $this->createUser([
            'first_name' => 'Alice',
            'last_name' => 'Walker',
            'email' => 'alice@example.com',
        ]);
        $match = $this->createUser([
            'first_name' => 'Bob',
            'last_name' => 'Walker',
            'email' => 'bob@example.com',
        ]);
        $this->createUser([
            'first_name' => 'Alice',
            'last_name' => 'Walker',
            'email' => 'alice2@example.com',
            'account_status' => 'deactivated',
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('api/users/search?q=Walker');

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $match->id);
    }

    public function test_user_search_returns_empty_data_for_blank_query(): void
    {
        $user = $this->createUser();

        Sanctum::actingAs($user);

        $response = $this->getJson('api/users/search?q=');

        $response->assertOk()
            ->assertJsonCount(0, 'data');
    }

    private function resetAssistantCache(): void
    {
        $reflection = new ReflectionClass('\App\Support\Assistant');
        $property = $reflection->getProperty('cachedUserId');
        $property->setAccessible(true);
        $property->setValue(null);
    }
}