<?php

namespace Tests\Feature\ApiRoutes;

use Tests\Support\ApiRouteDoubleTestCase;

class PublicApiRouteDoubleTest extends ApiRouteDoubleTestCase
{
    protected static function routeKeys(): array
    {
        return [
            'GET_posts',
            'GET_posts_show',
            'GET_posts_comments',
            'GET_users_show',
            'GET_users_followers',
            'GET_users_following',
            'GET_categories',
            'GET_categories_show',
            'GET_recipes',
            'GET_recipes_rankings',
            'GET_recipes_show',
            'GET_recipes_ratings',
        ];
    }
}
