<?php

namespace Tests\Feature\ApiRoutes;

use Tests\Support\ApiRouteDoubleTestCase;

class AuthApiRouteDoubleTest extends ApiRouteDoubleTestCase
{
    protected static function routeKeys(): array
    {
        return [
            'POST_register',
            'POST_login',
            'POST_forgot_password',
            'POST_reset_password',
            'POST_login_admin',
            'GET_user',
            'PATCH_user',
            'POST_user_profile_photo',
            'POST_logout',
            'POST_logout_admin',
            'POST_broadcasting_auth',
            'PATCH_me_deactivate',
        ];
    }
}
