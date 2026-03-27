<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;
use App\Models\PostComment;
use App\Notifications\CommentReceivedNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PostCommentController extends Controller
{
    /**
     * Store a new comment on a post. Notifies the post owner.
     */
    public function store(Request $request, Post $post): JsonResponse
    {
        $validated = $request->validate([
            'comment' => 'required|string|max:2000',
        ]);

        $user = $request->user();
        $comment = PostComment::create([
            'user_id' => $user->id,
            'post_id' => $post->id,
            'comment' => $validated['comment'],
        ]);

        $owner = $post->user;
        if ($owner && $owner->id !== $user->id) {
            $owner->notify(new CommentReceivedNotification(
                $post->id,
                $user->name,
                $validated['comment'],
                $post->recipe_id
            ));
        }

        return response()->json([
            'message' => 'Comment added',
            'comment' => [
                'id' => $comment->id,
                'comment' => $comment->comment,
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'profile_photo_url' => $this->fixMediaUrl($user->profile_photo_url ?? ''),
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
        $comments = $post->comments()
            ->with('user:id,first_name,last_name,profile_photo_url')
            ->orderBy('created_at', 'asc')
            ->get()
            ->map(fn (PostComment $c) => [
                'id' => $c->id,
                'comment' => $c->comment,
                'user' => [
                    'id' => $c->user->id,
                    'name' => $c->user->name,
                    'profile_photo_url' => $this->fixMediaUrl($c->user->profile_photo_url ?? ''),
                ],
                'created_at' => $c->created_at->toIso8601String(),
            ]);

        return response()->json(['comments' => $comments]);
    }

    private function fixMediaUrl(string $url): string
    {
        if ($url === '') {
            return '';
        }

        return str_replace('localhost:8000', 'localhost:8080', $url);
    }
}
