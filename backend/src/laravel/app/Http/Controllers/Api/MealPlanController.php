<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MealPlan;
use App\Models\MealPlanDaySkip;
use App\Models\MealPlanMealSkip;
use App\Services\ActivityLogService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MealPlanController extends Controller
{
    private function mondayWeekStart(string $plannedDate): string
    {
        return Carbon::parse($plannedDate)->startOfWeek(Carbon::MONDAY)->toDateString();
    }

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

        $startDate = $start->toDateString();
        $endDate = $start->copy()->addDays(6)->toDateString();

        $skippedDates = MealPlanDaySkip::query()
            ->where('user_id', $request->user()->id)
            ->whereBetween('skipped_date', [$startDate, $endDate])
            ->orderBy('skipped_date')
            ->pluck('skipped_date')
            ->map(fn ($d) => \Carbon\Carbon::parse($d)->toDateString())
            ->values();

        $skippedMeals = MealPlanMealSkip::query()
            ->where('user_id', $request->user()->id)
            ->whereBetween('skipped_date', [$startDate, $endDate])
            ->orderBy('skipped_date')
            ->orderBy('meal_slot')
            ->get(['skipped_date', 'meal_slot'])
            ->map(fn (MealPlanMealSkip $skip) => [
                'planned_date' => $skip->skipped_date->toDateString(),
                'meal_slot' => $skip->meal_slot,
            ])
            ->values();

        return response()->json([
            'data' => $data,
            'skipped_dates' => $skippedDates,
            'skipped_meals' => $skippedMeals,
        ]);
    }

    /**
     * POST /api/meal-plans/day-skip
     * Mark or clear "did not eat / skipped eating" for a calendar day.
     */
    public function setDaySkip(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'planned_date' => 'required|date',
            'did_not_eat' => 'required|boolean',
        ]);

        $userId = $request->user()->id;
        $date = $validated['planned_date'];

        if ($validated['did_not_eat']) {
            MealPlanDaySkip::updateOrCreate(
                [
                    'user_id' => $userId,
                    'skipped_date' => $date,
                ],
                [],
            );
        } else {
            MealPlanDaySkip::query()
                ->where('user_id', $userId)
                ->whereDate('skipped_date', $date)
                ->delete();
        }

        $week = $this->mondayWeekStart($date);
        if ($validated['did_not_eat']) {
            ActivityLogService::log(
                'meal_planner',
                'skip_day',
                "Marked {$date} as didn't eat (week {$week})",
                $userId,
                null,
                ['ip_address' => $request->ip()]
            );
        } else {
            ActivityLogService::log(
                'meal_planner',
                'unskip_day',
                "Cleared didn't eat for {$date} (week {$week})",
                $userId,
                null,
                ['ip_address' => $request->ip()]
            );
        }

        return response()->json(['message' => 'Day preference saved.']);
    }

    /**
     * POST /api/meal-plans/meal-skip
     * Mark or clear "skipped eating" for one meal slot on one day.
     */
    public function setMealSkip(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'planned_date' => 'required|date',
            'meal_slot' => 'required|string|max:20',
            'skipped' => 'required|boolean',
        ]);

        $userId = $request->user()->id;
        $date = $validated['planned_date'];
        $slot = $validated['meal_slot'];

        // When skipped=true we remove the meal plan row and record a skip marker (not just a flag).
        if ($validated['skipped']) {
            MealPlan::query()
                ->where('user_id', $userId)
                ->whereDate('planned_date', $date)
                ->where('meal_slot', $slot)
                ->delete();

            MealPlanMealSkip::updateOrCreate(
                [
                    'user_id' => $userId,
                    'skipped_date' => $date,
                    'meal_slot' => $slot,
                ],
                [],
            );
        } else {
            MealPlanMealSkip::query()
                ->where('user_id', $userId)
                ->whereDate('skipped_date', $date)
                ->where('meal_slot', $slot)
                ->delete();
        }

        $week = $this->mondayWeekStart($date);
        if ($validated['skipped']) {
            ActivityLogService::log(
                'meal_planner',
                'skip_meal',
                "Marked {$date} · {$slot} as skipped eating (week {$week})",
                $userId,
                null,
                ['ip_address' => $request->ip()]
            );
        } else {
            ActivityLogService::log(
                'meal_planner',
                'unskip_meal',
                "Cleared skipped eating for {$date} · {$slot} (week {$week})",
                $userId,
                null,
                ['ip_address' => $request->ip()]
            );
        }

        return response()->json(['message' => 'Meal preference saved.']);
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

        MealPlanMealSkip::query()
            ->where('user_id', $request->user()->id)
            ->whereDate('skipped_date', $validated['planned_date'])
            ->where('meal_slot', $validated['meal_slot'] ?? 'dinner')
            ->delete();

        $plan->load('recipe:id,title,prep_time');

        $recipe = $plan->recipe;
        $title = $recipe?->title ?? 'Recipe';
        $dateStr = $plan->planned_date->toDateString();
        $slot = $plan->meal_slot;
        $week = $this->mondayWeekStart($dateStr);
        ActivityLogService::log(
            'meal_planner',
            'assign_recipe',
            "Planned \"{$title}\" for {$dateStr} · {$slot} (week {$week})",
            $request->user()->id,
            $recipe,
            ['ip_address' => $request->ip()]
        );

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

        $mealPlan->loadMissing('recipe:id,title');
        $title = $mealPlan->recipe?->title ?? 'Recipe';
        $dateStr = $mealPlan->planned_date->toDateString();
        $slot = $mealPlan->meal_slot;
        $week = $this->mondayWeekStart($dateStr);
        ActivityLogService::log(
            'meal_planner',
            'remove_meal',
            "Removed \"{$title}\" from {$dateStr} · {$slot} (week {$week})",
            $request->user()->id,
            $mealPlan->recipe,
            ['ip_address' => $request->ip()]
        );

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
