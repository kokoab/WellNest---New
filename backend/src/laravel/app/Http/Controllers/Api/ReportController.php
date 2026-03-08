<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;
use App\Models\Recipe;
use App\Models\Report;
use App\Models\User;
use App\Notifications\ContentReportedNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    /**
     * Report a recipe. Notifies all admins.
     */
    public function reportRecipe(Request $request, Recipe $recipe): JsonResponse
    {
        $validated = $request->validate([
            'reason' => 'nullable|string|max:255',
            'details' => 'nullable|string|max:2000',
        ]);

        $user = $request->user();
        Report::create([
            'user_id' => $user->id,
            'reportable_type' => Recipe::class,
            'reportable_id' => $recipe->id,
            'reason' => $validated['reason'] ?? null,
            'details' => $validated['details'] ?? null,
        ]);

        $admins = User::where('is_admin', true)->get();
        foreach ($admins as $admin) {
            $admin->notify(new ContentReportedNotification(
                'recipe',
                $recipe->id,
                $user->name,
                $validated['reason'] ?? null,
                $validated['details'] ?? null
            ));
        }

        return response()->json(['message' => 'Recipe reported. Admins will review.'], 201);
    }

    /**
     * Report a post. Notifies all admins.
     */
    public function reportPost(Request $request, Post $post): JsonResponse
    {
        $validated = $request->validate([
            'reason' => 'nullable|string|max:255',
            'details' => 'nullable|string|max:2000',
        ]);

        $user = $request->user();
        Report::create([
            'user_id' => $user->id,
            'reportable_type' => Post::class,
            'reportable_id' => $post->id,
            'reason' => $validated['reason'] ?? null,
            'details' => $validated['details'] ?? null,
        ]);

        $admins = User::where('is_admin', true)->get();
        foreach ($admins as $admin) {
            $admin->notify(new ContentReportedNotification(
                'post',
                $post->id,
                $user->name,
                $validated['reason'] ?? null,
                $validated['details'] ?? null
            ));
        }

        return response()->json(['message' => 'Post reported. Admins will review.'], 201);
    }

    public function reportUser(Request $request, User $user): JsonResponse
    {
        if ($user->id === $request->user()->id) {
            return response()->json(['message' => 'You cannot report yourself.'], 400);
        }

        $validated = $request->validate([
            'reason' => 'required|string|max:255',
            'details' => 'nullable|string|max:2000',
        ]);

        Report::create([
            'user_id' => $request->user()->id,
            'reportable_type' => User::class,
            'reportable_id' => $user->id,
            'reason' => $validated['reason'],
            'details' => $validated['details'] ?? null
        ]);

        $admins = User::where('is_admin', true)->get();
        foreach ($admins as $admin) {
            $admin->notify(new ContentReportedNotification(
                'user',
                $user->id,
                $request->user()->name,
                $validated['reason'],
            ));
        }

        return response()->json(['message' => 'User reported. Admins will review'], 201);
    }
}
