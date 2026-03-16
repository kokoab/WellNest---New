<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class PostController extends Controller
{
    public function uploadImage(Request $request, Post $post): JsonResponse
    {
        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,jpg,png,gif,webp', 'max:5120'],
        ]);

        $file = $request->file('image');
        $path = $file->store('posts', 'public');
        $baseUrl = rtrim(config('app.url'), '/');
        $imageUrl = $baseUrl . '/storage/' . $path;

        $post->update(['image_url' => $imageUrl]);

        return response()->json([
            'message' => 'Image uploaded successfully',
            'image_url' => $imageUrl,
        ], 201);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'content' => 'required|string|max:5000',
            'title' => 'nullable|string|max:255',
            'recipe_id' => 'nullable|exists:recipes,id',
            'image_url' => 'nullable|string|max:500',
        ]);

        $post = Post::create([
            'user_id' => $request->user()->id,
            'content' => $validated['content'],
            'title' => $validated['title'] ?? null,
            'recipe_id' => $validated['recipe_id'] ?? null,
            'image_url' => $validated['image_url'] ?? null,
        ]);

        $post->load('user:id,first_name,last_name');

        return response()->json([
            'message' => 'Post created',
            'post' => [
                'id' => $post->id,
                'user_id' => $post->user_id,
                'recipe_id' => $post->recipe_id,
                'content' => $post->content,
                'image_url' => $post->image_url ?? '',
                'user' => ['id' => $post->user->id ?? null, 'name' => $post->user->name ?? ''],
            ],
        ], 201);
    }

    public function index(Request $request)
    {
        $query = Post::with('user:id,first_name,last_name')
            ->orderBy('created_at', 'desc');

        if ($request->filled('user_id')) {
            $query->where('user_id', $request->user_id);
        }

        return $query->get()
            ->map(fn (Post $p) => [
                'id' => $p->id,
                'user_id' => $p->user_id,
                'recipe_id' => $p->recipe_id,
                'content' => $p->content,
                'image_url' => $p->image_url ?? '',
                'created_at' => $p->created_at?->toIso8601String(),
                'user' => ['id' => $p->user->id ?? null, 'name' => trim(($p->user->first_name ?? '') . ' ' . ($p->user->last_name ?? ''))],
            ]);
    }
}
