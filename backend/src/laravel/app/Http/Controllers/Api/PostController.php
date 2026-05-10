<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Image;
use App\Models\Post;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;


class PostController extends Controller
{
    private const MAX_POST_IMAGES = 10;

    public function show(Request $request, Post $post): JsonResponse
    {
        $viewer = $request->user('sanctum');

        $post->load(['user:id,first_name,last_name,profile_photo_url', 'images']);
        $post->loadCount([
            'votes as likes_count',
            'comments as comments_count',
        ]);

        if ($viewer !== null) {
            $post->loadExists([
                'votes as is_liked' => fn ($q) => $q->where('user_id', $viewer->id),
            ]);
        }

        return response()->json($this->postDetailPayload($post));
    }

    public function uploadImage(Request $request, Post $post): JsonResponse
    {
        if ($post->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        if ($post->images()->count() >= self::MAX_POST_IMAGES) {
            return response()->json(['message' => 'Maximum '.self::MAX_POST_IMAGES.' images per post.'], 422);
        }

        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,jpg,png,gif,webp', 'max:5120'],
        ]);

        $file = $request->file('image');
        $path = $file->store('posts', 'public');

        $nextOrder = (int) ($post->images()->max('sort_order') ?? -1) + 1;

        $image = $post->images()->create([
            'path' => $path,
            'sort_order' => $nextOrder,
        ]);

        $this->syncPostCover($post);

        $baseUrl = rtrim(config('app.url'), '/');
        $url = $baseUrl . '/storage/' . $image->path;

        return response()->json([
            'message' => 'Image uploaded successfully',
            'image' => [
                'id' => $image->id,
                'sort_order' => (int) $image->sort_order,
                'url' => $this->fixImageUrl($url),
            ],
            'image_url' => $this->fixImageUrl($post->fresh()->image_url ?? ''),
        ], 201);
    }

    /** DELETE /api/posts/{post}/images/{image} */
    public function deleteImage(Request $request, Post $post, Image $image): JsonResponse
    {
        if ($post->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        if ($image->imageable_id !== $post->id || $image->imageable_type !== $post->getMorphClass()) {
            return response()->json(['message' => 'Image not found'], 404);
        }

        Storage::disk('public')->delete($image->path);
        $image->delete();
        $this->syncPostCover($post->fresh());

        return response()->json([
            'message' => 'Image deleted',
            'image_url' => $this->fixImageUrl($post->fresh()->image_url ?? ''),
        ], 200);
    }

    /** PUT /api/posts/{post}/images/reorder */
    public function reorderImages(Request $request, Post $post): JsonResponse
    {
        if ($post->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'image_ids' => ['required', 'array', 'max:'.self::MAX_POST_IMAGES],
            'image_ids.*' => ['integer', 'exists:images,id'],
        ]);

        $expected = $post->images()->pluck('id')->sort()->values()->all();
        $got = collect($validated['image_ids'])->sort()->values()->all();
        if ($expected !== $got || count($validated['image_ids']) !== count($expected)) {
            return response()->json(['message' => 'image_ids must list each post image exactly once'], 422);
        }

        foreach ($validated['image_ids'] as $index => $id) {
            Image::query()
                ->where('id', $id)
                ->where('imageable_id', $post->id)
                ->where('imageable_type', $post->getMorphClass())
                ->update(['sort_order' => $index]);
        }

        $this->syncPostCover($post->fresh());

        return response()->json([
            'message' => 'Order updated',
            'image_url' => $this->fixImageUrl($post->fresh()->image_url ?? ''),
        ], 200);
    }

    private function syncPostCover(Post $post): void
    {
        $first = $post->images()->orderBy('sort_order')->orderBy('id')->first();
        $baseUrl = rtrim(config('app.url'), '/');
        if ($first) {
            $post->update(['image_url' => $baseUrl . '/storage/' . $first->path]);
        } else {
            $post->update(['image_url' => null]);
        }
    }

    private function postDetailPayload(Post $post): array
    {
        $base = $this->postPayload($post);
        $baseUrl = rtrim(config('app.url'), '/');
        $base['images'] = $post->images->map(fn (Image $img) => [
            'id' => $img->id,
            'sort_order' => (int) $img->sort_order,
            'url' => $this->fixImageUrl($baseUrl . '/storage/' . $img->path),
        ])->values()->all();

        return $base;
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
        $viewer = $request->user('sanctum');

        $query = Post::with([
            'user:id,first_name,last_name,profile_photo_url',
            'images',
        ])
            ->withCount([
                'votes as likes_count',
                'comments as comments_count',
            ]);

        // Only filter by active users if not admin
        if (!$viewer || !$viewer->is_admin) {
            $query->whereHas('user', fn ($q) => $q->where('account_status', 'active'));
        }

        if ($request->filled('user_id')) {
            $query->where('user_id', $request->integer('user_id'));
        }

        if ($request->boolean('liked')) {
            if ($viewer === null) {
                return response()->json(['message' => 'Authentication required'], 401);
            }

            $query->whereHas('votes', function ($q) use ($viewer) {
                $q->where('user_id', $viewer->id);
            });
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

        if ($request->filled('search')) {
            $like = $this->sqlLikePattern((string) $request->input('search'));
            $query->where(function ($q) use ($like) {
                $q->where('posts.title', 'like', $like)
                    ->orWhere('posts.content', 'like', $like)
                    ->orWhereHas('user', function ($uq) use ($like) {
                        $uq->whereRaw("CONCAT(COALESCE(first_name,''), ' ', COALESCE(last_name,'')) LIKE ?", [$like])
                            ->orWhere('first_name', 'like', $like)
                            ->orWhere('last_name', 'like', $like);
                    })
                    ->orWhereHas('recipe', function ($rq) use ($like) {
                        $rq->where('title', 'like', $like)
                            ->orWhere('description', 'like', $like)
                            ->orWhereHas('category', fn ($cq) => $cq->where('name', 'like', $like))
                            ->orWhereHas('ingredients', fn ($iq) => $iq->where('name', 'like', $like));
                    });
            });
        }

        $sort = strtolower((string) $request->query('sort', ''));
        if ($sort === 'popular') {
            $query->orderByDesc('likes_count')->orderByDesc('posts.created_at');
        } else {
            $query->orderByDesc('posts.created_at');
        }

        if ($viewer !== null) {
            $query->withExists([
                'votes as is_liked' => fn ($q) => $q->where('user_id', $viewer->id),
            ]);
        }

        $perPage = max(1, min(100, (int) $request->query('per_page', 10)));
        $page = max(1, (int) $request->query('page', 1));

        $paginator = $query->paginate($perPage, ['*'], 'page', $page);

        $posts = $paginator->getCollection()->map(fn (Post $post) => $this->postDetailPayload($post));

        return response()->json([
            'data' => $posts,
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
            'links' => [
                'next' => $paginator->nextPageUrl(),
                'prev' => $paginator->previousPageUrl(),
            ],
        ]);
    }

    private function postPayload(Post $post): array
    {
        return [
            'id' => $post->id,
            'user_id' => $post->user_id,
            'recipe_id' => $post->recipe_id,
            'title' => $post->title,
            'content' => $post->content,
            'image_url' => $this->fixImageUrl($post->image_url ?? ''),
            'created_at' => $post->created_at?->toIso8601String(),
            'likes_count' => (int) ($post->likes_count ?? 0),
            'comments_count' => (int) ($post->comments_count ?? 0),
            'is_liked' => (bool) ($post->is_liked ?? false),
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

    /** Escapes LIKE wildcards in user input; wraps with %. */
    private function sqlLikePattern(string $raw): string
    {
        $t = trim($raw);
        $escaped = addcslashes($t, '%_\\');

        return '%'.$escaped.'%';
    }

    public function update(Request $request, Post $post): JsonResponse
    {
        if ((int) $request->user()->id !== (int) $post->user_id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'content' => 'required|string|max:5000',
            'title' => 'nullable|string|max:255',
            'recipe_id' => 'nullable|exists:recipes,id',
        ]);

        $post->update($validated);

        $post->refresh();
        $post->load(['user:id,first_name,last_name,profile_photo_url', 'images']);
        $post->loadCount([
            'votes as likes_count',
            'comments as comments_count',
        ]);

        $viewer = $request->user('sanctum');
        if ($viewer !== null) {
            $post->loadExists([
                'votes as is_liked' => fn ($q) => $q->where('user_id', $viewer->id),
            ]);
        }

        return response()->json([
            'message' => 'Post updated',
            'post' => $this->postDetailPayload($post),
        ]);
    }

    public function destroy(Request $request, Post $post): JsonResponse
    {
        if ((int) $request->user()->id !== (int) $post->user_id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $post->load('images');
        foreach ($post->images as $image) {
            Storage::disk('public')->delete($image->path);
            $image->delete();
        }

        $post->delete();

        return response()->json(['message' => 'Post deleted']);
    }
}
