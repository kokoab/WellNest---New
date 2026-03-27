<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;
use App\Models\PostComment;
use App\Notifications\CommentReceivedNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;

class PostCommentController extends Controller
{
    /**
     * Convert storage path/URL into a public absolute URL.
     */
    private function toAbsoluteImageUrl(?string $url): ?string
    {
        if (!$url || trim($url) === '') {
            return null;
        }

        if (str_starts_with($url, 'http://') || str_starts_with($url, 'https://')) {
            return $url;
        }

        $baseUrl = rtrim(config('app.url'), '/');
        if (str_starts_with($url, '/')) {
            return $baseUrl . $url;
        }

        return $baseUrl . '/storage/' . ltrim($url, '/');
    }

    /**
     * Store a new comment on a post. Notifies the post owner.
     * Accepts optional image upload (multipart/form-data).
     */
    public function store(Request $request, Post $post): JsonResponse
    {
        $validated = $request->validate([
            'comment'  => 'nullable|string|max:2000',
            'image'    => 'nullable|image|max:5120', // 5MB max
        ]);

        // Must have at least a comment or an image
        if (empty($validated['comment']) && !$request->hasFile('image')) {
            return response()->json(['message' => 'Comment or image is required.'], 422);
        }

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('comment-images', 'public');
            $imageUrl = $this->toAbsoluteImageUrl(Storage::disk('public')->url($path));
        }

        $user = $request->user();
        $payload = [
            'user_id'   => $user->id,
            'post_id'   => $post->id,
            'comment'   => $validated['comment'] ?? '',
        ];

        // Keep comments working even if image_url migration is not yet applied.
        if (Schema::hasColumn('post_comments', 'image_url')) {
            $payload['image_url'] = $imageUrl;
        }

        $comment = PostComment::create($payload);

        $owner = $post->user;
        if ($owner && $owner->id !== $user->id) {
            $owner->notify(new CommentReceivedNotification(
                $post->id,
                $user->name,
                $validated['comment'] ?? '📷 Image',
                $post->recipe_id
            ));
        }

        return response()->json([
            'message' => 'Comment added',
            'comment' => [
                'id'        => $comment->id,
                'comment'   => $comment->comment,
                'image_url' => $this->toAbsoluteImageUrl($comment->image_url),
                'user'      => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'profile_photo_url' => $user->profile_photo_url ?? null,
                ],
                'created_at' => $comment->created_at->toIso8601String(),
            ],
        ], 201);
    }

    /**
     * List comments for a post.
     */
    public function index(Post $post): JsonResponse
    {
        $hasImageUrl = Schema::hasColumn('post_comments', 'image_url');

        $comments = $post->comments()
            ->with('user:id,first_name,last_name,profile_photo_url')
            ->orderBy('created_at', 'asc')
            ->limit(50)
            ->get()
            ->map(fn (PostComment $c) => [
                'id'        => $c->id,
                'comment'   => $c->comment,
                'image_url' => $hasImageUrl ? $this->toAbsoluteImageUrl($c->image_url) : null,
                'user'      => [
                    'id' => $c->user->id,
                    'name' => $c->user->name,
                    'profile_photo_url' => $c->user->profile_photo_url ?? null,
                ],
                'created_at' => $c->created_at->toIso8601String(),
            ]);

        return response()->json(['comments' => $comments]);
    }
}