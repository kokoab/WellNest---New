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
        $query = $request->user()
            ->savedRecipes()
            ->with([
                'category:id,name',
                'user:id,first_name,last_name',
                'images:id,path,imageable_id,imageable_type',
            ])
            ->withAvg('ratings as average_rating', 'rating')
            ->withCount('ratings');

        if ($request->filled('search')) {
            $like = $this->sqlLikePattern((string) $request->input('search'));
            $query->where(function ($q) use ($like) {
                $q->where('recipes.title', 'like', $like)
                    ->orWhere('recipes.description', 'like', $like)
                    ->orWhereHas('category', fn ($cq) => $cq->where('name', 'like', $like))
                    ->orWhereHas('ingredients', fn ($iq) => $iq->where('name', 'like', $like))
                    ->orWhereHas('user', function ($uq) use ($like) {
                        $uq->whereRaw("CONCAT(COALESCE(first_name,''), ' ', COALESCE(last_name,'')) LIKE ?", [$like])
                            ->orWhere('first_name', 'like', $like)
                            ->orWhere('last_name', 'like', $like);
                    });
            });
        }

        $sort = strtolower((string) $request->query('sort', ''));
        if ($sort === 'popular') {
            $query->orderByDesc('ratings_count')
                ->orderByDesc('average_rating')
                ->orderByDesc('saved_recipes.created_at');
        } else {
            $query->orderBy('saved_recipes.created_at', 'desc');
        }

        $perPage = max(1, min(100, (int) $request->query('per_page', 15)));
        $page = max(1, (int) $request->query('page', 1));

        $recipes = $query->paginate($perPage, ['*'], 'page', $page);

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

    /** Escapes LIKE wildcards in user input; wraps with %. */
    private function sqlLikePattern(string $raw): string
    {
        $t = trim($raw);
        $escaped = addcslashes($t, '%_\\');

        return '%'.$escaped.'%';
    }
}
