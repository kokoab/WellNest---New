<?php

namespace Tests\Feature\ApiRoutes;

use Tests\Support\ApiRouteDoubleTestCase;

class AdminApiRouteDoubleTest extends ApiRouteDoubleTestCase
{
    protected static function routeKeys(): array
    {
        return [
            'POST_register_admin',
            'GET_admin_users',
            'PATCH_admin_users_status',
            'DELETE_admin_users',
            'POST_admin_categories',
            'PUT_admin_categories',
            'DELETE_admin_categories',
            'GET_admin_reports',
            'PATCH_admin_reports_approve',
            'PATCH_admin_reports_remove_content',
            'PATCH_admin_reports_suspend_user',
            'PATCH_admin_reports_unban_user',
            'PATCH_admin_reports_dismiss',
            'DELETE_admin_reports',
            'GET_admin_audit_logs',
            'GET_admin_audit_logs_export',
            'GET_admin_recipes_rankings',
            'GET_admin_stats_overview',
            'GET_admin_stats_user_growth',
            'GET_admin_stats_post_frequency',
            'GET_admin_stats_chatbot_interactions',
        ];
    }
}
