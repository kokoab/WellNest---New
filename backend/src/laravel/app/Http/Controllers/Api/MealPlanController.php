<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MealPlan;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class MealPlanController extends Controller
{
    /**
     * GET /api/meal-plans?week_start=YYYY-MM-DD
     * Returns meal plans for a 7-day window starting at week_start.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'week_start' => 'required|date',
        ]);

        $start = \Carbon\Carbon::parse($request->query('week_start'))->startOfDay();
        $end = $start->copy()->addDays(6)->endOfDay();

        $plans = MealPlan::where('user_id', $request->user()->id)
            ->whereBetween('planned_date', [$start, $end])
            ->with([
                'recipe:id,title,prep_time,user_id',
                'recipe.category:id,name',
                'recipe.images:id,path,imageable_id,imageable_type',
            ])
            ->orderBy('planned_date')
            ->get();

        $baseUrl = rtrim(config('app.url'), '/');

        $data = $plans->map(function (MealPlan $plan) use ($baseUrl) {
            $recipe = $plan->recipe;
            $firstImage = $recipe?->images->first();
            return [
                'id' => $plan->id,
                'recipe_id' => $plan->recipe_id,
                'planned_date' => $plan->planned_date->toDateString(),
                'meal_slot' => $plan->meal_slot,
                'recipe' => $recipe ? [
                    'id' => $recipe->id,
                    'title' => $recipe->title,
                    'prep_time' => $recipe->prep_time,
                    'category' => $recipe->category?->name,
                    'image_url' => $firstImage ? $baseUrl . '/storage/' . $firstImage->path : null,
                ] : null,
            ];
        });

        return response()->json(['data' => $data]);
    }

    /**
     * POST /api/meal-plans
     * Assign a recipe to a date/slot. Upserts on (user, date, slot).
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'recipe_id' => 'required|exists:recipes,id',
            'planned_date' => 'required|date',
            'meal_slot' => 'sometimes|string|max:20',
        ]);

        $plan = MealPlan::updateOrCreate(
            [
                'user_id' => $request->user()->id,
                'planned_date' => $validated['planned_date'],
                'meal_slot' => $validated['meal_slot'] ?? 'dinner',
            ],
            [
                'recipe_id' => $validated['recipe_id'],
            ],
        );

        $plan->load('recipe:id,title,prep_time');

        return response()->json([
            'id' => $plan->id,
            'recipe_id' => $plan->recipe_id,
            'planned_date' => $plan->planned_date->toDateString(),
            'meal_slot' => $plan->meal_slot,
            'recipe' => $plan->recipe ? [
                'id' => $plan->recipe->id,
                'title' => $plan->recipe->title,
                'prep_time' => $plan->recipe->prep_time,
            ] : null,
        ], 201);
    }

    /**
     * DELETE /api/meal-plans/{mealPlan}
     */
    public function destroy(Request $request, MealPlan $mealPlan): JsonResponse
    {
        if ($mealPlan->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        $mealPlan->delete();

        return response()->json(['message' => 'Meal plan removed.']);
    }

    /**
     * GET /api/meal-plans/export?week_start=YYYY-MM-DD
     * Returns the meal plan data for PDF generation by the client.
     */
    public function export(Request $request): JsonResponse
    {
        $request->validate([
            'week_start' => 'required|date',
        ]);

        $start = \Carbon\Carbon::parse($request->query('week_start'))->startOfDay();
        $end = $start->copy()->addDays(6)->endOfDay();

        $plans = MealPlan::where('user_id', $request->user()->id)
            ->whereBetween('planned_date', [$start, $end])
            ->with('recipe:id,title,prep_time')
            ->orderBy('planned_date')
            ->get();

        $rows = $plans->map(fn (MealPlan $p) => [
            'date' => $p->planned_date->toDateString(),
            'day' => $p->planned_date->format('l'),
            'meal_slot' => $p->meal_slot,
            'recipe_title' => $p->recipe?->title ?? '—',
            'prep_time' => $p->recipe?->prep_time,
        ]);

        return response()->json([
            'week_start' => $start->toDateString(),
            'week_end' => $end->toDateString(),
            'user_name' => $request->user()->name,
            'meals' => $rows,
        ]);
    }
}
