<?php

namespace App\Http\Controllers;

use App\Models\Image;
use App\Models\Recipe;
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
        $validated = $request->validate([
            'category_id' => 'required|exists:categories,id',
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'instructions' => 'required|string',
            'prep_time' => 'required|integer',
            'ingredients' => 'nullable|array',
            'ingredients.*.name' => 'required|string|max:255',
            'ingredients.*.quantity' => 'nullable|numeric|min:0',
            'ingredients.*.unit' => 'nullable|string|max:50',
        ]);

        $validated['user_id'] = $request->user()->id;
        $ingredientsData = $validated['ingredients'] ?? [];
        unset($validated['ingredients']);

        $recipe = Recipe::create($validated);
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


        $viewer = $this->userFromOptionalBearer($request);
        if ($viewer) {
            RecipeView::firstOrCreate([
                'recipe_id' => $recipe->id,
                'user_id' => $viewer->id,
                'view_date' => now()->toDateString(),
            ]);
        }

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

        $validated = $request->validate([
            'category_id' => 'sometimes|exists:categories,id',
            'title' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'instructions' => 'sometimes|string',
            'prep_time' => 'sometimes|integer',
            'ingredients' => 'nullable|array',
            'ingredients.*.name' => 'required|string|max:255',
            'ingredients.*.quantity' => 'nullable|numeric|min:0',
            'ingredients.*.unit' => 'nullable|string|max:50',
        ]);

        $ingredientsData = $validated['ingredients'] ?? null;
        unset($validated['ingredients']);
        $recipe->update($validated);
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
}
