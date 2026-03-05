<?php

namespace App\Http\Controllers;

use App\Models\Category;
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
}
