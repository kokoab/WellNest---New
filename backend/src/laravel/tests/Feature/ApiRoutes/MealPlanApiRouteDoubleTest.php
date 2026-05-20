<?php

namespace Tests\Feature\ApiRoutes;

use Tests\Support\ApiRouteDoubleTestCase;

class MealPlanApiRouteDoubleTest extends ApiRouteDoubleTestCase
{
    protected static function routeKeys(): array
    {
        return [
            'GET_meal_plans_export',
            'GET_meal_plans',
            'POST_meal_plans',
            'POST_meal_plans_day_skip',
            'POST_meal_plans_meal_skip',
            'DELETE_meal_plans',
            'POST_meal_planner_log',
        ];
    }
}
