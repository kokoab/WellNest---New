<?php

namespace Tests\Feature\ApiRoutes;

use Tests\Support\ApiRouteDoubleTestCase;

class PostApiRouteDoubleTest extends ApiRouteDoubleTestCase
{
    protected static function routeKeys(): array
    {
        return [
            'POST_posts',
            'PUT_posts',
            'DELETE_posts',
            'POST_posts_images',
            'DELETE_posts_images',
            'PUT_posts_images_reorder',
            'GET_posts_likes',
            'POST_posts_like',
            'DELETE_posts_like',
            'POST_posts_report',
            'POST_posts_comments',
        ];
    }
}
