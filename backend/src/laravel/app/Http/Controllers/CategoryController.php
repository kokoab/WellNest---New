<?php

namespace App\Http\Controllers;

use App\Models\Category;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\Rule;

class CategoryController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index(): JsonResponse
    {
        //
        $categories = Category::orderBy('name')->get();
        return response()->json($categories, 200);
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create(Request $request): JsonResponse
    {
        //
        $validated = $request->validate([
            'name' => 'required|string|max:255|unique:categories,name',
            'description' => 'required|string|max:255',
        ]);

        $category = Category::create($validated);
        return response()->json($category, 201);
    }

    /**
     * Find a category whose name matches case-insensitively, or create it.
     */
    public function findOrCreateForRecipe(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string|max:255',
        ]);

        $name = trim($validated['name']);
        if ($name === '') {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => ['name' => ['The name field is required.']],
            ], 422);
        }

        $category = $this->categoryByNameCaseInsensitive($name)->first();
        if ($category) {
            return response()->json($category, 200);
        }

        try {
            $category = Category::create([
                'name' => $name,
                'description' => trim($validated['description'] ?? '') ?: 'User-created recipe category.',
            ]);
        } catch (QueryException $e) {
            if (($e->errorInfo[0] ?? null) !== '23000') {
                throw $e;
            }

            $category = $this->categoryByNameCaseInsensitive($name)->first();
            if ($category) {
                return response()->json($category, 200);
            }

            throw $e;
        }

        return response()->json($category, 201);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function show(Category $category): JsonResponse
    {
        //
        return response()->json($category, 200);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, Category $category): JsonResponse
    {
        //
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255', Rule::unique('categories')->ignore($category->id)],
            'description' => 'required|string|max:255',
        ]);

        $category->update($validated);
        return response()->json($category, 200);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function delete(Category $category): JsonResponse
    {
        //
        $category->delete();
        return response()->json(['message' => 'Category deleted successfully'], 200);
    }

    private function categoryByNameCaseInsensitive(string $name)
    {
        return Category::whereRaw('LOWER(name) = LOWER(?)', [$name]);
    }
}
