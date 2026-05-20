<?php

namespace Tests\Feature\ApiRoutes;

use Tests\Support\ApiRouteDoubleTestCase;

class SocialApiRouteDoubleTest extends ApiRouteDoubleTestCase
{
    protected static function routeKeys(): array
    {
        return [
            'GET_notifications',
            'GET_notifications_unread_count',
            'PATCH_notifications_read',
            'POST_notifications_read_all',
            'GET_users_search',
            'POST_users_follow',
            'DELETE_users_follow',
            'POST_users_report',
        ];
    }
}
