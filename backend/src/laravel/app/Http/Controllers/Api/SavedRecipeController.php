<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Recipe;
use App\Models\SavedRecipe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SavedRecipeController extends Controller
{
    /** POST /api/recipes/{recipe}/save — add to saved (auth required) */
    public function save(Request $request, Recipe $recipe): JsonResponse
    {
        $user = $request->user();
        SavedRecipe::firstOrCreate(
            ['user_id' => $user->id, 'recipe_id' => $recipe->id]
        );
        return response()->json(['message' => 'Recipe saved.'], 201);
    }

    /** DELETE /api/recipes/{recipe}/save — remove from saved */
    public function unsave(Request $request, Recipe $recipe): JsonResponse
    {
        SavedRecipe::where('user_id', $request->user()->id)
            ->where('recipe_id', $recipe->id)
            ->delete();
        return response()->json(['message' => 'Recipe removed from saved.'], 200);
    }

    /** GET /api/saved-recipes — list current user's saved recipes (paginated) */
    public function index(Request $request): JsonResponse
    {
        $recipes = $request->user()
            ->savedRecipes()
            ->with([
                'category:id,name',
                'user:id,first_name,last_name',
                'images:id,path,imageable_id,imageable_type',
            ])
            ->withAvg('ratings as average_rating', 'rating')
            ->withCount('ratings')
            ->orderBy('saved_recipes.created_at', 'desc')
            ->paginate(15);

        $baseUrl = rtrim(config('app.url'), '/');
        $data = $recipes->toArray();
        foreach (array_keys($data['data']) as $i) {
            $recipe = $recipes->getCollection()[$i];
            $firstImage = $recipe->images->first();
            $data['data'][$i]['image_url'] = $firstImage ? $baseUrl . '/storage/' . $firstImage->path : null;
            $data['data'][$i]['average_rating'] = round((float) ($recipe->average_rating ?? 0), 1);
            $data['data'][$i]['ratings_count'] = (int) ($recipe->ratings_count ?? 0);
        }

        return response()->json($data);
    }

    /** GET /api/recipes/{recipe}/saved — check if current user saved this recipe */
    public function check(Request $request, Recipe $recipe): JsonResponse
    {
        $saved = SavedRecipe::where('user_id', $request->user()->id)
            ->where('recipe_id', $recipe->id)
            ->exists();
        return response()->json(['saved' => $saved]);
    }
}
