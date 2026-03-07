<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;
use App\Models\Recipe;
use App\Models\Vote;
use App\Notifications\PostLikedNotification;
use App\Notifications\RecipeLikedNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class VoteController extends Controller
{
    /**
     * Like a recipe. Notifies the recipe owner when liked.
     */
    public function likeRecipe(Request $request, Recipe $recipe): JsonResponse
    {
        $user = $request->user();
        $existing = Vote::where('user_id', $user->id)
            ->where('votable_type', Recipe::class)
            ->where('votable_id', $recipe->id)
            ->first();

        if ($existing) {
            return response()->json(['message' => 'Already liked', 'liked' => true]);
        }

        Vote::create([
            'user_id' => $user->id,
            'votable_type' => Recipe::class,
            'votable_id' => $recipe->id,
            'vote' => true,
        ]);

        $owner = $recipe->user;
        if ($owner && $owner->id !== $user->id) {
            $owner->notify(new RecipeLikedNotification(
                $recipe->id,
                $recipe->title,
                $user->name
            ));
        }

        return response()->json(['message' => 'Recipe liked', 'liked' => true], 201);
    }

    /**
     * Unlike a recipe.
     */
    public function unlikeRecipe(Request $request, Recipe $recipe): JsonResponse
    {
        Vote::where('user_id', $request->user()->id)
            ->where('votable_type', Recipe::class)
            ->where('votable_id', $recipe->id)
            ->delete();

        return response()->json(['message' => 'Recipe unliked', 'liked' => false]);
    }

    /**
     * Like a post. Could add PostLikedNotification if needed later.
     */
    public function likePost(Request $request, Post $post): JsonResponse
    {
        $user = $request->user();
        $existing = Vote::where('user_id', $user->id)
            ->where('votable_type', Post::class)
            ->where('votable_id', $post->id)
            ->first();

        if ($existing) {
            return response()->json(['message' => 'Already liked', 'liked' => true]);
        }

        Vote::create([
            'user_id' => $user->id,
            'votable_type' => Post::class,
            'votable_id' => $post->id,
            'vote' => true,
        ]);

        $owner = $post->user;
        if ($owner && $owner->id !== $user->id) {
            $owner->notify(new PostLikedNotification($post->id, $user->name));
        }

        return response()->json(['message' => 'Post liked', 'liked' => true], 201);
    }

    /**
     * Unlike a post.
     */
    public function unlikePost(Request $request, Post $post): JsonResponse
    {
        Vote::where('user_id', $request->user()->id)
            ->where('votable_type', Post::class)
            ->where('votable_id', $post->id)
            ->delete();

        return response()->json(['message' => 'Post unliked', 'liked' => false]);
    }
}
