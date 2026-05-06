<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;
use App\Models\Recipe;
use Illuminate\Http\JsonResponse;

class AdminStatsController extends Controller
{
    /**
     * Lightweight counts for the admin overview (avoids loading full post lists).
     */
    public function summary(): JsonResponse
    {
        return response()->json([
            'posts_total' => Post::query()->count(),
            'recipes_total' => Recipe::query()->count(),
        ]);
    }
}
