<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use RuntimeException;
use App\Models\User;
use App\Models\Category;
use App\Models\Recipe;
use App\Models\Post;
use App\Models\Ingredient;

abstract class TestCase extends BaseTestCase
{
    public function createApplication()
    {
        putenv('APP_ENV=testing');
        putenv('DB_CONNECTION=sqlite');
        putenv('DB_DATABASE=:memory:');
        $_ENV['APP_ENV'] = 'testing';
        $_ENV['DB_CONNECTION'] = 'sqlite';
        $_ENV['DB_DATABASE'] = ':memory:';
        $_SERVER['APP_ENV'] = 'testing';
        $_SERVER['DB_CONNECTION'] = 'sqlite';
        $_SERVER['DB_DATABASE'] = ':memory:';

        $app = require __DIR__.'/../bootstrap/app.php';
        $app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

        $defaultConnection = (string) config('database.default');
        $sqliteDatabase = (string) config('database.connections.sqlite.database');
        $environment = (string) app()->environment();

        if ($environment !== 'testing' || $defaultConnection !== 'sqlite' || $sqliteDatabase !== ':memory:') {
            throw new RuntimeException(
                "Unsafe test database configuration detected. ".
                "Expected APP_ENV=testing with sqlite :memory:, got ".
                "APP_ENV={$environment}, DB_CONNECTION={$defaultConnection}, sqlite.database={$sqliteDatabase}"
            );
        }

        return $app;
    }

    protected function createAdmin(array $attributes = [])
    {
        return User::factory()->admin()->create(array_merge([
            'status' => 'active',
            'account_status' => 'active',
        ], $attributes));
    }

    protected function createUser(array $attributes = [])
    {
        return User::factory()->regular()->create(array_merge([
            'status' => 'active',
            'account_status' => 'active',
        ], $attributes));
    }

    protected function createCategory(array $attributes = [])
    {
        return Category::factory()->create($attributes);
    }

    protected function createRecipe(array $attributes = [])
    {
        return Recipe::factory()->create($attributes);
    }

    protected function createIngredient(array $attributes = [])
    {
        return Ingredient::factory()->create($attributes);
    }

    protected function createPost(array $attributes = [])
    {
        return Post::factory()->create($attributes);
    } 



}
