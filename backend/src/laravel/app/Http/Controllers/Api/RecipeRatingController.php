<?php

namespace App\Http\Controllers\Api;

use App\Events\UnreadNotificationBadgeUpdated;
use App\Http\Controllers\Controller;
use App\Models\Recipe;
use App\Models\RecipeRating;
use App\Notifications\RecipeRatedNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RecipeRatingController extends Controller
{
    /**
     * Store or update a rating for a recipe. One rating per user per recipe.
     */
    public function store(Request $request, Recipe $recipe): JsonResponse
    {
        $validated = $request->validate([
            'rating' => 'required|integer|min:1|max:5',
            'comment' => 'nullable|string|max:1000',
        ]);

        $user = $request->user();
        $existing = RecipeRating::where('recipe_id', $recipe->id)
            ->where('user_id', $user->id)
            ->first();

        if ($existing) {
            $hadComment = !empty(trim($existing->comment ?? ''));
            $existing->update($validated);
            $owner = $recipe->user;
            $comment = $validated['comment'] ?? null;
            $hasNewComment = !$hadComment && !empty(trim($comment ?? ''));
            if ($owner && $owner->id !== $user->id && $hasNewComment) {
                $owner->notify(new RecipeRatedNotification(
                    $recipe->id,
                    $recipe->title,
                    $user->name,
                    $validated['rating'],
                    $comment
                ));
                event(new UnreadNotificationBadgeUpdated($owner->id));
            }
            return response()->json([
                'message' => 'Rating updated',
                'rating' => $this->formatRating($existing->fresh(['user:id,first_name,last_name'])),
            ], 200);
        }

        $rating = RecipeRating::create([
            'recipe_id' => $recipe->id,
            'user_id' => $user->id,
            'rating' => $validated['rating'],
            'comment' => $validated['comment'] ?? null,
        ]);

        $rating->load(['user:id,first_name,last_name']);

        $owner = $recipe->user;
        if ($owner && $owner->id !== $user->id) {
            $owner->notify(new RecipeRatedNotification(
                $recipe->id,
                $recipe->title,
                $user->name,
                $validated['rating'],
                $validated['comment'] ?? null
            ));
            event(new UnreadNotificationBadgeUpdated($owner->id));
        }

        return response()->json([
            'message' => 'Rating submitted',
            'rating' => $this->formatRating($rating),
        ], 201);
    }

    /**
     * Get all ratings/reviews for a recipe (public).
     */
    public function index(Recipe $recipe): JsonResponse
    {
        $ratings = $recipe->ratings()
            ->with('user:id,first_name,last_name')
            ->orderBy('created_at', 'desc')
            ->get();

        $stats = [
            'average_rating' => round($recipe->ratings()->avg('rating') ?? 0, 1),
            'ratings_count' => $recipe->ratings()->count(),
        ];

        return response()->json([
            'data' => $ratings->map(fn ($r) => $this->formatRating($r)),
            'average_rating' => $stats['average_rating'],
            'ratings_count' => $stats['ratings_count'],
        ]);
    }

    /**
     * Get current user's rating for a recipe (auth required).
     */
    public function userRating(Request $request, Recipe $recipe): JsonResponse
    {
        $rating = RecipeRating::where('recipe_id', $recipe->id)
            ->where('user_id', $request->user()->id)
            ->first();

        if (!$rating) {
            return response()->json(['rating' => null]);
        }

        return response()->json([
            'rating' => $this->formatRating($rating->load('user:id,first_name,last_name')),
        ]);
    }

    private function formatRating(RecipeRating $r): array
    {
        $user = $r->user;
        return [
            'id' => $r->id,
            'recipe_id' => $r->recipe_id,
            'user_id' => $r->user_id,
            'rating' => $r->rating,
            'comment' => $r->comment,
            'created_at' => $r->created_at?->toIso8601String(),
            'user' => $user ? [
                'id' => $user->id,
                'first_name' => $user->first_name,
                'last_name' => $user->last_name,
            ] : null,
        ];
    }
}
