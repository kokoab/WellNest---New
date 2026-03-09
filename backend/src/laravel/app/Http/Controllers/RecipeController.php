<?php

namespace App\Http\Controllers;

use App\Models\Image;
use App\Models\Recipe;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;
use App\Services\ActivityLogService;

class RecipeController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Recipe::with(['category:id,name', 'user:id,first_name,last_name', 'images:id,path,imageable_id,imageable_type'])->orderBy('created_at', 'desc');

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
                    });
            });
        }

        $recipes = $query->paginate(10);
        $data = $recipes->toArray();
        $baseUrl = rtrim(config('app.url'), '/');
        foreach ($data['data'] as $i => $recipeData) {
            $recipe = $recipes->getCollection()[$i];
            $firstImage = $recipe->images->first();
            $data['data'][$i]['image_url'] = $firstImage ? $baseUrl . '/storage/' . $firstImage->path : null;
            $data['data'][$i]['average_rating'] = round($recipe->ratings()->avg('rating') ?? 0, 1);
            $data['data'][$i]['ratings_count'] = $recipe->ratings()->count();
        }
        return response()->json($data);
    }
    /**
     * Show the form for creating a new resource.
     */
    public function create(Request $request)
    {
        //
        $validated = $request->validate([
            'category_id' => 'required|exists:categories,id',
            'title' => 'required|string|max:255',
            'instructions' => 'required|string',
            'prep_time' => 'required|integer',
        ]);

        $validated['user_id'] = $request->user()->id;
        $recipe = Recipe::create($validated);
        ActivityLogService::log('recipe', 'create', 'Recipe created successfully', $request->user()->id, $recipe);
        return response()->json([
            'message' => 'Recipe created successfully',
            'id' => $recipe->id,
        ], 201);
    }


    /**
     * Display the specified resource.
     */
    public function show(Recipe $recipe): JsonResponse
    {
        $recipe->load([
            'category:id,name',
            'user:id,first_name,last_name',
            'ingredients:id,name',
        ]);

        $data = $recipe->toArray();
        $baseUrl = rtrim(config('app.url'), '/');
        $firstImage = $recipe->images()->first();
        $data['image_url'] = $firstImage ? $baseUrl . '/storage/' . $firstImage->path : null;
        $data['average_rating'] = round($recipe->ratings()->avg('rating') ?? 0, 1);
        $data['ratings_count'] = $recipe->ratings()->count();

        return response()->json($data);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, Recipe $recipe): JsonResponse
    {
        //
        $validated = $request->validate([
            'category_id' => 'sometimes|exists:categories,id',
            'title' => 'sometimes|string|max:255',
            'instructions' => 'sometimes|string',
            'prep_time' => 'sometimes|integer',
        ]);

        $recipe->update($validated);
        ActivityLogService::log('recipe', 'update', 'Recipe updated successfully', $request->user()->id, $recipe);
        return response()->json(['message' => 'Recipe updated successfully'], 200);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function delete(Recipe $recipe, Request $request): JsonResponse
    {
        foreach ($recipe->images as $image) {
            Storage::disk('public')->delete($image->path);
        }
        $recipe->delete();
        ActivityLogService::log('recipe', 'delete', 'Recipe deleted successfully', $request->user()->id, $recipe);
        return response()->json(['message' => 'Recipe deleted successfully'], 200);
    }

    /**
     * Upload an image for the recipe.
     */
    public function uploadImage(Request $request, Recipe $recipe): JsonResponse
    {
        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,jpg,png,gif,webp', 'max:5120'],
        ]);

        $file = $request->file('image');
        $path = $file->store('recipes', 'public');

        $recipe->images()->create([
            'path' => $path,
        ]);

        $image = $recipe->images()->latest()->first();
        $imageUrl = rtrim(config('app.url'), '/') . '/storage/' . $image->path;

        return response()->json([
            'message' => 'Image uploaded successfully',
            'image_url' => $imageUrl,
        ], 201);
    }
}
