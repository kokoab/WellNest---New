<?php

namespace App\Http\Controllers;

use App\Models\Image;
use App\Models\Recipe;
use App\Models\RecipeStep;
use App\Models\RecipeView;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\PersonalAccessToken;
use App\Services\ActivityLogService;

class RecipeController extends Controller
{
    /**
     * Public recipe routes do not use auth:sanctum, so $request->user() is null even with a valid Bearer token.
     * Resolve the user from the token so view counts and optional personalization work.
     */
    protected function userFromOptionalBearer(Request $request): ?User
    {
        if ($user = $request->user()) {
            return $user instanceof User ? $user : null;
        }
        $plain = $request->bearerToken();
        if (! $plain) {
            return null;
        }
        $accessToken = PersonalAccessToken::findToken($plain);
        if (! $accessToken) {
            return null;
        }
        $model = $accessToken->tokenable;

        return $model instanceof User ? $model : null;
    }
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Recipe::with(['category:id,name', 'user:id,first_name,last_name', 'images:id,path,imageable_id,imageable_type'])->orderBy('created_at', 'desc');
        $range = $request->query('range');

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        if ($request->filled('user_id')) {
            $query->where('user_id', $request->user_id);
        }

        if ($request->boolean('liked')) {
            $viewer = $this->userFromOptionalBearer($request);
            if ($viewer === null) {
                return response()->json(['message' => 'Authentication required'], 401);
            }

            $query->whereHas('votes', function ($q) use ($viewer) {
                $q->where('user_id', $viewer->id);
            });
        }

        if ($request->filled('search')) {
            $term = $request->search;
            $query->where(function ($q) use ($term) {
                $q->where('title', 'like', '%' . $term . '%')
                    ->orWhereHas('ingredients', function ($q2) use ($term) {
                        $q2->where('name', 'like', '%' . $term . '%');
                    })
                    ->orWhereHas('user', function ($q3) use ($term) {
                        $q3->whereRaw("CONCAT(first_name, ' ', last_name) LIKE ?", ['%' . $term . '%'])
                             ->orWhere('first_name', 'like', '%' . $term . '%')
                              ->orWhere('last_name', 'like', '%' . $term . '%');
                    });
            });
        }

        $startDate = $this->resolveStartDate($range);
        if ($startDate !== null) {
            $query->where('created_at', '>=', $startDate);
        }

        $recipes = $query->paginate(10);
        $data = $recipes->toArray();
        $baseUrl = rtrim(config('app.url'), '/');
        foreach ($data['data'] as $i => $recipeData) {
            $recipe = $recipes->getCollection()[$i];
            $cover = $recipe->images->first();
            $data['data'][$i]['image_url'] = $cover ? $baseUrl . '/storage/' . $cover->path : null;
            $data['data'][$i]['average_rating'] = round($recipe->ratings()->avg('rating') ?? 0, 1);
            $data['data'][$i]['ratings_count'] = $recipe->ratings()->count();
            $data['data'][$i]['views_count'] = $recipe->views()->count();
        }
        return response()->json($data);
    }

    private function resolveStartDate(?string $range): ?Carbon
    {
        return match ($range) {
            'weekly' => now()->subWeek(),
            'monthly' => now()->subMonth(),
            'yearly' => now()->subYear(),
            default => null,
        };
    }
    /**
     * Show the form for creating a new resource.
     */
    public function create(Request $request)
    {
        $hasSteps = $this->requestHasNonEmptySteps($request);

        $rules = [
            'category_id' => 'required|exists:categories,id',
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'prep_timing_mode' => 'nullable|in:overall,per_step',
            'ingredients' => 'nullable|array',
            'ingredients.*.name' => 'required|string|max:255',
            'ingredients.*.quantity' => 'nullable|numeric|min:0',
            'ingredients.*.unit' => 'nullable|string|max:50',
        ];

        if ($hasSteps) {
            $rules['instructions'] = 'nullable|string';
            $rules['prep_time'] = 'nullable|integer|min:0|max:10080';
            $rules['steps'] = 'required|array|min:1|max:80';
            $rules['steps.*.title'] = 'nullable|string|max:255';
            $rules['steps.*.instructions'] = 'nullable|string';
            $rules['steps.*.prep_time_minutes'] = 'nullable|integer|min:0|max:10080';
            $rules['steps.*.id'] = 'prohibited';
        } else {
            $rules['instructions'] = 'required|string';
            $rules['prep_time'] = 'required|integer|min:1|max:10080';
        }

        $validated = $request->validate($rules);

        $stepErrors = $this->validateStepBodies($hasSteps ? ($validated['steps'] ?? []) : []);
        if ($stepErrors !== []) {
            return response()->json(['message' => 'Validation failed', 'errors' => $stepErrors], 422);
        }

        $timingMode = $validated['prep_timing_mode'] ?? 'overall';
        if ($hasSteps && $timingMode === 'overall') {
            $pt = (int) ($validated['prep_time'] ?? 0);
            if ($pt < 1) {
                return response()->json([
                    'message' => 'Validation failed',
                    'errors' => ['prep_time' => ['Overall prep time is required when using overall timing.']],
                ], 422);
            }
        }

        $validated['user_id'] = $request->user()->id;
        $validated['prep_timing_mode'] = $hasSteps ? $timingMode : 'overall';

        $stepsPayload = $hasSteps ? $validated['steps'] : [];
        unset($validated['steps']);

        $ingredientsData = $validated['ingredients'] ?? [];
        unset($validated['ingredients']);

        if ($hasSteps) {
            $validated['instructions'] = $this->flattenStepsToInstructionsText($stepsPayload);
            if ($timingMode === 'per_step') {
                $validated['prep_time'] = $this->sumStepPrepMinutes($stepsPayload);
            } else {
                $validated['prep_time'] = (int) $validated['prep_time'];
            }
        }

        $recipe = Recipe::create($validated);
        if ($hasSteps) {
            $this->syncSteps($recipe, $stepsPayload);
        }

        $this->syncIngredients($recipe, $ingredientsData);
        ActivityLogService::log('recipe', 'create', 'Recipe created successfully', $request->user()->id, $recipe);
        return response()->json([
            'message' => 'Recipe created successfully',
            'id' => $recipe->id,
        ], 201);
    }

    protected function syncIngredients(Recipe $recipe, array $ingredientsData): void
    {
        $recipe->ingredients()->detach();
        foreach ($ingredientsData as $item) {
            $name = trim($item['name'] ?? '');
            if ($name === '') continue;
            $ingredient = \App\Models\Ingredient::firstOrCreate(['name' => $name]);
            $quantity = (int) round((float) ($item['quantity'] ?? 0));
            if ($quantity < 1) $quantity = 1;
            $unit = trim($item['unit'] ?? '') ?: 'unit';
            $recipe->ingredients()->attach($ingredient->id, ['quantity' => $quantity, 'unit' => $unit]);
        }
    }


    /**
     * Display the specified resource.
     */
    public function show(Recipe $recipe, Request $request): JsonResponse
    {
        $recipe->load([
            'category:id,name',
            'user:id,first_name,last_name',
            'ingredients:id,name',
            'steps.images',
        ]);

        $data = $recipe->toArray();
        $baseUrl = rtrim(config('app.url'), '/');
        $ordered = $recipe->images()->orderBy('sort_order')->orderBy('id')->get();
        $cover = $ordered->first();
        $data['image_url'] = $cover ? $baseUrl . '/storage/' . $cover->path : null;
        $data['images'] = $ordered->map(fn (Image $img) => [
            'id' => $img->id,
            'sort_order' => (int) $img->sort_order,
            'url' => $baseUrl . '/storage/' . $img->path,
        ])->values()->all();
        $data['average_rating'] = round($recipe->ratings()->avg('rating') ?? 0, 1);
        $data['ratings_count'] = $recipe->ratings()->count();
        $data['views_count'] = $recipe->views()->count();
        $data['prep_timing_mode'] = $recipe->prep_timing_mode ?? 'overall';
        $data['steps'] = $recipe->steps->map(function (RecipeStep $step) use ($baseUrl) {
            $img = $step->images->first();

            return [
                'id' => $step->id,
                'sort_order' => (int) $step->sort_order,
                'title' => $step->title,
                'instructions' => $step->instructions,
                'prep_time_minutes' => $step->prep_time_minutes,
                'image' => $img ? [
                    'id' => $img->id,
                    'sort_order' => (int) $img->sort_order,
                    'url' => $baseUrl.'/storage/'.$img->path,
                ] : null,
            ];
        })->values()->all();

        $viewer = $this->userFromOptionalBearer($request);
        $isLiked = false;
        if ($viewer) {
            $isLiked = $recipe->votes()->where('user_id', $viewer->id)->exists();
            RecipeView::firstOrCreate([
                'recipe_id' => $recipe->id,
                'user_id' => $viewer->id,
                'view_date' => now()->toDateString(),
            ]);
        }
        $data['is_liked'] = $isLiked;

        return response()->json($data);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, Recipe $recipe): JsonResponse
    {
        if ($recipe->user_id !== $request->user()->id) {
            return response()->json(['message' => 'You are not authorized to update this recipe'], 403);
        }

        $stepsKeyPresent = $request->exists('steps');
        $hasSteps = $stepsKeyPresent && is_array($request->input('steps')) && count($request->input('steps')) > 0;

        $rules = [
            'category_id' => 'sometimes|exists:categories,id',
            'title' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'prep_timing_mode' => 'nullable|in:overall,per_step',
            'ingredients' => 'nullable|array',
            'ingredients.*.name' => 'required|string|max:255',
            'ingredients.*.quantity' => 'nullable|numeric|min:0',
            'ingredients.*.unit' => 'nullable|string|max:50',
        ];

        if ($stepsKeyPresent) {
            if ($hasSteps) {
                $rules['instructions'] = 'nullable|string';
                $rules['prep_time'] = 'nullable|integer|min:0|max:10080';
                $rules['steps'] = 'required|array|min:1|max:80';
                $rules['steps.*.title'] = 'nullable|string|max:255';
                $rules['steps.*.instructions'] = 'nullable|string';
                $rules['steps.*.prep_time_minutes'] = 'nullable|integer|min:0|max:10080';
                $rules['steps.*.id'] = 'nullable|integer|exists:recipe_steps,id';
            } else {
                $rules['instructions'] = 'required|string';
                $rules['prep_time'] = 'required|integer|min:1|max:10080';
            }
        } else {
            $rules['instructions'] = 'sometimes|string';
            $rules['prep_time'] = 'sometimes|integer|min:0|max:10080';
        }

        $validated = $request->validate($rules);

        if ($hasSteps) {
            $idErr = $this->validateStepIdsForRecipe($recipe, $validated['steps']);
            if ($idErr !== null) {
                return response()->json(['message' => 'Validation failed', 'errors' => $idErr], 422);
            }
            $stepErrors = $this->validateStepBodies($validated['steps']);
            if ($stepErrors !== []) {
                return response()->json(['message' => 'Validation failed', 'errors' => $stepErrors], 422);
            }
            $timingMode = $validated['prep_timing_mode'] ?? $recipe->prep_timing_mode ?? 'overall';
            if ($timingMode === 'overall') {
                $pt = (int) ($validated['prep_time'] ?? $recipe->prep_time ?? 0);
                if ($pt < 1) {
                    return response()->json([
                        'message' => 'Validation failed',
                        'errors' => ['prep_time' => ['Overall prep time is required when using overall timing.']],
                    ], 422);
                }
            }
        }

        $stepsPayload = $hasSteps ? $validated['steps'] : null;
        unset($validated['steps']);

        $ingredientsData = $validated['ingredients'] ?? null;
        unset($validated['ingredients']);

        if ($hasSteps && $stepsPayload !== null) {
            $timingMode = $validated['prep_timing_mode'] ?? $recipe->prep_timing_mode ?? 'overall';
            $validated['prep_timing_mode'] = $timingMode;
            $validated['instructions'] = $this->flattenStepsToInstructionsText($stepsPayload);
            if ($timingMode === 'per_step') {
                $validated['prep_time'] = $this->sumStepPrepMinutes($stepsPayload);
            } elseif (array_key_exists('prep_time', $validated)) {
                $validated['prep_time'] = (int) $validated['prep_time'];
            }
        }

        $recipe->update($validated);

        if ($stepsKeyPresent) {
            if ($hasSteps && $stepsPayload !== null) {
                $this->syncSteps($recipe, $stepsPayload);
                $recipe->refresh();
                $recipe->instructions = $this->flattenStepsToInstructionsText(
                    $recipe->steps()->orderBy('sort_order')->orderBy('id')->get()->map(fn (RecipeStep $s) => [
                        'title' => $s->title,
                        'instructions' => $s->instructions,
                    ])->all()
                );
                if (($recipe->prep_timing_mode ?? 'overall') === 'per_step') {
                    $recipe->prep_time = (int) $recipe->steps()->sum('prep_time_minutes');
                }
                $recipe->save();
            } else {
                $this->purgeRecipeSteps($recipe);
                $recipe->refresh();
                $recipe->prep_timing_mode = 'overall';
                $recipe->save();
            }
        }

        if ($ingredientsData !== null) {
            $this->syncIngredients($recipe, $ingredientsData);
        }
        ActivityLogService::log('recipe', 'update', 'Recipe updated successfully', $request->user()->id, $recipe);
        return response()->json(['message' => 'Recipe updated successfully'], 200);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function delete(Recipe $recipe, Request $request): JsonResponse
    {

        if ($recipe->user_id !== $request->user()->id) {
            return response()->json(['message' => 'You are not authorized to update this recipe'], 403);
        }

        $recipe->load('steps.images');
        foreach ($recipe->steps as $step) {
            $this->deleteStepImages($step);
            $step->delete();
        }

        foreach ($recipe->images as $image) {
            Storage::disk('public')->delete($image->path);
        }
        $recipe->delete();
        ActivityLogService::log('recipe', 'delete', 'Recipe deleted successfully', $request->user()->id, $recipe);
        return response()->json(['message' => 'Recipe deleted successfully'], 200);
    }

    /**
     * Upload an image for the recipe (append, max 10). First by sort_order is the list thumbnail.
     */
    public function uploadImage(Request $request, Recipe $recipe): JsonResponse
    {
        if ($recipe->user_id !== $request->user()->id) {
            return response()->json(['message' => 'You are not authorized to update this recipe'], 403);
        }

        if ($recipe->images()->count() >= 10) {
            return response()->json(['message' => 'Maximum 10 images per recipe.'], 422);
        }

        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,jpg,png,gif,webp', 'max:5120'],
        ]);

        $file = $request->file('image');
        $path = $file->store('recipes', 'public');

        $nextOrder = (int) ($recipe->images()->max('sort_order') ?? -1) + 1;

        $image = $recipe->images()->create([
            'path' => $path,
            'sort_order' => $nextOrder,
        ]);

        $baseUrl = rtrim(config('app.url'), '/');
        $imageUrl = $baseUrl . '/storage/' . $image->path;

        return response()->json([
            'message' => 'Image uploaded successfully',
            'image' => [
                'id' => $image->id,
                'sort_order' => (int) $image->sort_order,
                'image_url' => str_replace('localhost:8000', 'localhost:8080', $imageUrl),
            ],
        ], 201);
    }

    /** DELETE /api/recipes/{recipe}/images/{image} */
    public function deleteImage(Request $request, Recipe $recipe, Image $image): JsonResponse
    {
        if ($recipe->user_id !== $request->user()->id) {
            return response()->json(['message' => 'You are not authorized to update this recipe'], 403);
        }

        if ($image->imageable_id !== $recipe->id || $image->imageable_type !== $recipe->getMorphClass()) {
            return response()->json(['message' => 'Image not found'], 404);
        }

        Storage::disk('public')->delete($image->path);
        $image->delete();

        return response()->json(['message' => 'Image deleted'], 200);
    }

    /** PUT /api/recipes/{recipe}/images/reorder — body: { "image_ids": [3,1,2] } */
    public function reorderImages(Request $request, Recipe $recipe): JsonResponse
    {
        if ($recipe->user_id !== $request->user()->id) {
            return response()->json(['message' => 'You are not authorized to update this recipe'], 403);
        }

        $validated = $request->validate([
            'image_ids' => ['required', 'array', 'max:10'],
            'image_ids.*' => ['integer', 'exists:images,id'],
        ]);

        $expected = $recipe->images()->pluck('id')->sort()->values()->all();
        $got = collect($validated['image_ids'])->sort()->values()->all();
        if ($expected !== $got || count($validated['image_ids']) !== count($expected)) {
            return response()->json(['message' => 'image_ids must list each recipe image exactly once'], 422);
        }

        foreach ($validated['image_ids'] as $index => $id) {
            Image::query()
                ->where('id', $id)
                ->where('imageable_id', $recipe->id)
                ->where('imageable_type', $recipe->getMorphClass())
                ->update(['sort_order' => $index]);
        }

        return response()->json(['message' => 'Order updated'], 200);
    }

    /** POST /api/recipes/{recipe}/steps/{step}/images — one photo per step (replaces existing). */
    public function uploadStepImage(Request $request, Recipe $recipe, RecipeStep $step): JsonResponse
    {
        if ($recipe->user_id !== $request->user()->id) {
            return response()->json(['message' => 'You are not authorized to update this recipe'], 403);
        }
        if ($step->recipe_id !== $recipe->id) {
            return response()->json(['message' => 'Step not found'], 404);
        }

        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,jpg,png,gif,webp', 'max:5120'],
        ]);

        $this->deleteStepImages($step);

        $file = $request->file('image');
        $path = $file->store('recipe-steps', 'public');

        $image = $step->images()->create([
            'path' => $path,
            'sort_order' => 0,
        ]);

        $baseUrl = rtrim(config('app.url'), '/');
        $imageUrl = $baseUrl.'/storage/'.$image->path;

        return response()->json([
            'message' => 'Step image uploaded successfully',
            'image' => [
                'id' => $image->id,
                'sort_order' => (int) $image->sort_order,
                'image_url' => str_replace('localhost:8000', 'localhost:8080', $imageUrl),
            ],
        ], 201);
    }

    /** DELETE /api/recipes/{recipe}/steps/{step}/images/{image} */
    public function deleteStepImage(Request $request, Recipe $recipe, RecipeStep $step, Image $image): JsonResponse
    {
        if ($recipe->user_id !== $request->user()->id) {
            return response()->json(['message' => 'You are not authorized to update this recipe'], 403);
        }
        if ($step->recipe_id !== $recipe->id) {
            return response()->json(['message' => 'Step not found'], 404);
        }
        if ($image->imageable_id !== $step->id || $image->imageable_type !== $step->getMorphClass()) {
            return response()->json(['message' => 'Image not found'], 404);
        }

        Storage::disk('public')->delete($image->path);
        $image->delete();

        return response()->json(['message' => 'Step image deleted'], 200);
    }

    protected function requestHasNonEmptySteps(Request $request): bool
    {
        return $request->has('steps')
            && is_array($request->input('steps'))
            && count($request->input('steps')) > 0;
    }

    /**
     * @return array<string, array<int, string>>
     */
    protected function validateStepBodies(array $steps): array
    {
        $errors = [];
        foreach ($steps as $i => $step) {
            $t = trim((string) ($step['title'] ?? ''));
            $ins = trim((string) ($step['instructions'] ?? ''));
            if ($t === '' && $ins === '') {
                $errors["steps.$i"] = ['Each step needs a title and/or instructions.'];
            }
        }

        return $errors;
    }

    /**
     * @return array<string, array<int, string>>|null
     */
    protected function validateStepIdsForRecipe(Recipe $recipe, array $steps): ?array
    {
        foreach ($steps as $i => $step) {
            $id = $step['id'] ?? null;
            if ($id === null) {
                continue;
            }
            $exists = RecipeStep::where('recipe_id', $recipe->id)->where('id', (int) $id)->exists();
            if (! $exists) {
                return ["steps.$i.id" => ['Invalid step id for this recipe.']];
            }
        }

        return null;
    }

    protected function syncSteps(Recipe $recipe, array $stepsPayload): void
    {
        $keepIds = [];
        foreach ($stepsPayload as $row) {
            if (! empty($row['id'])) {
                $keepIds[] = (int) $row['id'];
            }
        }

        $existingIds = $recipe->steps()->pluck('id')->map(fn ($id) => (int) $id)->all();
        $toDelete = array_diff($existingIds, $keepIds);
        foreach ($recipe->steps()->whereIn('id', $toDelete)->get() as $step) {
            $this->deleteStepImages($step);
            $step->delete();
        }

        foreach ($stepsPayload as $index => $row) {
            $title = isset($row['title']) ? trim((string) $row['title']) : '';
            $title = $title === '' ? null : $title;
            $instr = isset($row['instructions']) ? trim((string) $row['instructions']) : '';
            $instr = $instr === '' ? null : $instr;
            $prepMin = array_key_exists('prep_time_minutes', $row) && $row['prep_time_minutes'] !== null
                ? (int) $row['prep_time_minutes']
                : null;

            $attrs = [
                'sort_order' => $index,
                'title' => $title,
                'instructions' => $instr,
                'prep_time_minutes' => $prepMin,
            ];

            if (! empty($row['id'])) {
                $step = RecipeStep::where('recipe_id', $recipe->id)->where('id', (int) $row['id'])->first();
                if ($step) {
                    $step->update($attrs);

                    continue;
                }
            }
            $recipe->steps()->create($attrs);
        }
    }

    protected function purgeRecipeSteps(Recipe $recipe): void
    {
        $recipe->load('steps.images');
        foreach ($recipe->steps as $step) {
            $this->deleteStepImages($step);
            $step->delete();
        }
    }

    protected function deleteStepImages(RecipeStep $step): void
    {
        foreach ($step->images as $image) {
            Storage::disk('public')->delete($image->path);
            $image->delete();
        }
    }

    /**
     * @param  array<int, array<string, mixed>>  $steps
     */
    protected function flattenStepsToInstructionsText(array $steps): string
    {
        $parts = [];
        foreach ($steps as $i => $s) {
            $title = isset($s['title']) ? trim((string) $s['title']) : '';
            $inst = isset($s['instructions']) ? trim((string) $s['instructions']) : '';
            $n = $i + 1;
            if ($title !== '' && $inst !== '') {
                $parts[] = "Step {$n}: {$title}\n{$inst}";
            } elseif ($title !== '') {
                $parts[] = "Step {$n}: {$title}";
            } elseif ($inst !== '') {
                $parts[] = "Step {$n}\n{$inst}";
            }
        }

        return implode("\n\n", $parts);
    }

    /**
     * @param  array<int, array<string, mixed>>  $steps
     */
    protected function sumStepPrepMinutes(array $steps): int
    {
        $sum = 0;
        foreach ($steps as $s) {
            if (isset($s['prep_time_minutes']) && $s['prep_time_minutes'] !== null) {
                $sum += (int) $s['prep_time_minutes'];
            }
        }

        return $sum;
    }
}
