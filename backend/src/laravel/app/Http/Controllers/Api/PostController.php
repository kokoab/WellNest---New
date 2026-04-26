<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;


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
            'image_url' => $this->fixImageUrl($imageUrl),
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

        $post->load('user:id,first_name,last_name,profile_photo_url');

        return response()->json([
            'message' => 'Post created',
            'post' => $this->postPayload($post),
        ], 201);
    }

    public function index(Request $request): JsonResponse
    {
        $query = Post::with('user:id,first_name,last_name,profile_photo_url')
            ->whereHas('user', fn ($q) => $q->where('account_status', 'active'))
            ->orderBy('created_at', 'desc');

        if ($request->filled('user_id')) {
            $query->where('user_id', $request->integer('user_id'));
        }

        $feed = strtolower((string) $request->query('feed', ''));
        if ($feed === 'following' || $request->boolean('following')) {
            $viewer = $request->user('sanctum');

            if ($viewer === null) {
                return response()->json([]);
            }

            $followingIds = $viewer->following()->pluck('users.id');

            if ($followingIds->isEmpty()) {
                return response()->json([]);
            }

            $query->whereIn('user_id', $followingIds);
        }

        $posts = $query->get()->map(fn (Post $post) => $this->postPayload($post));

        return response()->json($posts);
    }

    private function postPayload(Post $post): array
    {
        return [
            'id' => $post->id,
            'user_id' => $post->user_id,
            'recipe_id' => $post->recipe_id,
            'content' => $post->content,
            'image_url' => $this->fixImageUrl($post->image_url ?? ''),
            'created_at' => $post->created_at?->toIso8601String(),
            'user' => $this->postUserPayload($post->user),
        ];
    }

    /** @param \App\Models\User|null $user */
    private function postUserPayload($user): array
    {
        if ($user === null) {
            return ['id' => null, 'name' => '', 'profile_photo_url' => ''];
        }

        return [
            'id' => $user->id,
            'name' => trim(($user->first_name ?? '') . ' ' . ($user->last_name ?? '')),
            'profile_photo_url' => $this->fixImageUrl($user->profile_photo_url ?? ''),
        ];
    }

    private function fixImageUrl(string $url): string
    {
        if ($url === '') {
            return '';
        }

        return str_replace('localhost:8000', 'localhost:8080', $url);
    }
}
