<?php

namespace App\Http\Controllers;

use App\Models\Recipe;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class RecipeController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Recipe::with(['category:id,name', 'user:id,first_name,last_name'])->orderBy('created_at', 'desc');

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
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
        return response()->json($recipes);
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
        return response()->json(['message' => 'Recipe created successfully'], 200);
    }


    /**
     * Display the specified resource.
     */
    public function show(Recipe $recipe): JsonResponse
    {
        //

        $recipe->load(['category:id,name', 'user:id,first_name,last_name']);
        return response()->json($recipe);
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
        return response()->json(['message' => 'Recipe updated successfully'], 200);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function delete(Recipe $recipe): JsonResponse
    {
        //
        $recipe->delete();
        return response()->json(['message' => 'Recipe deleted successfully'], 200);
    }
}
