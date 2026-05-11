<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class PasswordResetApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_forgot_password_returns_generic_message_for_known_user(): void
    {
        $this->createUser(['email' => 'known@example.com']);

        $response = $this->postJson('api/forgot-password', [
            'email' => 'known@example.com',
        ]);

        $response->assertOk()
            ->assertJsonFragment(['message' => 'If that email exists, a reset code has been sent.']);
    }

    public function test_forgot_password_requires_email(): void
    {
        $response = $this->postJson('api/forgot-password', []);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }

    public function test_reset_password_rejects_invalid_code(): void
    {
        $this->createUser(['email' => 'u@example.com']);

        $response = $this->postJson('api/reset-password', [
            'email' => 'u@example.com',
            'code' => '000000',
            'password' => 'newpassword1',
            'password_confirmation' => 'newpassword1',
        ]);

        $response->assertStatus(422)
            ->assertJsonFragment(['message' => 'The reset code is invalid or expired.']);
    }

    public function test_reset_password_updates_password_when_code_valid(): void
    {
        $email = 'reset-ok@example.com';
        $user = $this->createUser([
            'email' => $email,
            'password' => Hash::make('oldpassword1'),
        ]);

        $plainCode = '654321';
        Cache::put('password-reset-code:'.strtolower($email), Hash::make($plainCode), now()->addMinutes(10));

        $response = $this->postJson('api/reset-password', [
            'email' => $email,
            'code' => $plainCode,
            'password' => 'brandnewpass1',
            'password_confirmation' => 'brandnewpass1',
        ]);

        $response->assertOk()
            ->assertJsonFragment(['message' => 'Password reset successfully.']);

        $this->assertTrue(Hash::check('brandnewpass1', $user->fresh()->password));
    }
}
