<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Recipe;
use App\Services\ActivityLogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MealPlannerController extends Controller
{
    /**
     * POST /api/meal-planner/log
     * Stores planner actions in activity logs so admins can audit/export them.
     */
    public function logAction(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'action' => 'required|string|max:100',
            'day' => 'required|date',
            'week_start' => 'required|date',
            'recipe_id' => 'nullable|integer|exists:recipes,id',
            'recipe_title' => 'nullable|string|max:255',
        ]);

        $action = (string) $validated['action'];
        $day = (string) $validated['day'];
        $weekStart = (string) $validated['week_start'];
        $recipeTitle = isset($validated['recipe_title']) ? trim((string) $validated['recipe_title']) : null;
        $recipeId = isset($validated['recipe_id']) ? (int) $validated['recipe_id'] : null;

        $recipe = $recipeId ? Recipe::find($recipeId) : null;
        $recipeLabel = $recipeTitle ?: ($recipe?->title ?: 'Unknown recipe');

        $description = match ($action) {
            'assign_recipe' => "Planned \"{$recipeLabel}\" for {$day} (week {$weekStart})",
            'clear_day' => "Cleared meal plan for {$day} (week {$weekStart})",
            default => "Meal planner action \"{$action}\" on {$day} (week {$weekStart})",
        };

        ActivityLogService::log(
            'meal_planner',
            $action,
            $description,
            $request->user()->id,
            $recipe,
            ['ip_address' => $request->ip()]
        );

        return response()->json(['message' => 'Meal planner activity logged'], 201);
    }
}
