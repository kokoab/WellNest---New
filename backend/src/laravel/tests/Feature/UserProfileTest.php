<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use ReflectionClass;
use Tests\TestCase;

class UserProfileTest extends TestCase
{
    use RefreshDatabase;

    // GET /api/user

    public function test_get_user_authenticated_user_can_fetch_current_profile(): void
    {
        $user = $this->createUser([
            'first_name' => 'Profile',
            'last_name' => 'User',
            'email' => 'profile-user@example.com',
        ]);
        Sanctum::actingAs($user);

        $this->getJson('api/user')
            ->assertOk()
            ->assertJsonPath('email', 'profile-user@example.com')
            ->assertJsonPath('first_name', 'Profile');
    }

    public function test_get_user_guest_is_unauthorized(): void
    {
        $this->getJson('api/user')->assertUnauthorized();
    }

    // GET /api/users/search

    public function test_get_users_search_authenticated_user_finds_matches(): void
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
        Sanctum::actingAs($user);

        $this->getJson('api/users/search?q=Walker')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $match->id);
    }

    public function test_get_users_search_authenticated_user_gets_empty_for_blank_query(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->getJson('api/users/search?q=')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_get_users_search_guest_is_unauthorized(): void
    {
        $this->getJson('api/users/search?q=test')->assertUnauthorized();
    }

    // GET /api/users/{user}

    public function test_get_user_profile_authenticated_user_can_view_other_user(): void
    {
        $viewer = $this->createUser();
        $subject = $this->createUser(['first_name' => 'Public', 'last_name' => 'Profile']);
        Sanctum::actingAs($viewer);

        $this->getJson("api/users/{$subject->id}")
            ->assertOk()
            ->assertJsonFragment([
                'id' => $subject->id,
                'first_name' => 'Public',
                'last_name' => 'Profile',
            ])
            ->assertJsonPath('is_following', false);
    }

    public function test_get_user_profile_authenticated_user_gets_404_for_missing(): void
    {
        Sanctum::actingAs($this->createUser());

        $this->getJson('api/users/999999')->assertNotFound();
    }

    public function test_get_user_profile_guest_is_unauthorized(): void
    {
        $subject = $this->createUser();

        $this->getJson("api/users/{$subject->id}")->assertUnauthorized();
    }

    private function resetAssistantCache(): void
    {
        $reflection = new ReflectionClass('\App\Support\Assistant');
        $property = $reflection->getProperty('cachedUserId');
        $property->setAccessible(true);
        $property->setValue(null);
    }
}
