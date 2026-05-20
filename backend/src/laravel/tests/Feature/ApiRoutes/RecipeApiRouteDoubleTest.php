<?php

namespace Tests\Feature\ApiRoutes;

use Tests\Support\ApiRouteDoubleTestCase;

class RecipeApiRouteDoubleTest extends ApiRouteDoubleTestCase
{
    protected static function routeKeys(): array
    {
        return [
            'POST_categories_for_recipe',
            'POST_recipes',
            'PUT_recipes',
            'DELETE_recipes',
            'POST_recipes_images',
            'DELETE_recipes_images',
            'PUT_recipes_images_reorder',
            'POST_recipes_steps_images',
            'DELETE_recipes_steps_images',
            'POST_recipes_like',
            'DELETE_recipes_like',
            'POST_recipes_report',
            'POST_recipes_ratings',
            'GET_recipes_ratings_me',
            'POST_recipes_save',
            'DELETE_recipes_save',
            'GET_saved_recipes',
            'GET_recipes_saved',
        ];
    }
}
