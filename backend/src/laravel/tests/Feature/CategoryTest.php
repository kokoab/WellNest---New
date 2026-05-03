<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;

/**
 * 1. test if can create
 * 2. correct input
 * 3. incorrect input
 * 4. forbidden (403)
 * 5. unauthorized (404)
 * 
 * 
 * 
 * 
 * 
 */

class CategoryTest extends TestCase
{
    /**
     * A basic feature test example.
     */
    public function test_example(): void
    {
        $response = $this->get('/');

        $response->assertStatus(200);
    }
}
