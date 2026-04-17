<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Support\Assistant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

class UserController extends Controller
{
    /**
     * GET /api/users/search?q=... — search users by name (for starting a chat). Excludes current user.
     */
    public function search(Request $request): JsonResponse
    {
        $q = $request->get('q', '');
        $q = trim((string) $q);
        $userId = Auth::id();

        if ($q === '') {
            return response()->json(['data' => []], 200);
        }

        $botId = Assistant::botUserId();

        $users = User::query()
            ->where('id', '!=', $userId)
            ->when($botId, fn ($q) => $q->where('id', '!=', $botId))
            ->where(function ($query) use ($q) {
                $query->where('first_name', 'like', "%{$q}%")
                    ->orWhere('last_name', 'like', "%{$q}%")
                    ->orWhereRaw("CONCAT(COALESCE(first_name,''), ' ', COALESCE(last_name,'')) LIKE ?", ["%{$q}%"]);
            })
            ->select('id', 'first_name', 'last_name', 'profile_photo_url')
            ->limit(20)
            ->get()
            ->map(fn (User $u) => [
                'id' => $u->id,
                'name' => $u->name,
                'profile_photo_url' => $this->fixMediaUrl($u->profile_photo_url ?? ''),
            ]);

        return response()->json(['data' => $users], 200);
    }

    private function fixMediaUrl(string $url): string
    {
        if ($url === '') {
            return '';
        }

        return str_replace('localhost:8000', 'localhost:8080', $url);
    }

    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        //
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        //
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        //
    }

    /**
     * Display the specified resource.
     */
    public function show(User $user)
    {
        $user->loadCount(['followers', 'following']);

        $viewer = request()->user('sanctum');

        return response()->json($this->publicProfilePayload($user, $viewer));
    }

    public function follow(Request $request, User $user): JsonResponse
    {
        $viewer = $request->user();

        if ($viewer->is($user)) {
            return response()->json([
                'message' => 'You cannot follow yourself.',
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        $alreadyFollowing = $viewer->following()
            ->where('users.id', $user->id)
            ->exists();

        if ($alreadyFollowing) {
            return response()->json([
                'message' => 'You are already following this user.',
            ], Response::HTTP_CONFLICT);
        }

        $viewer->following()->attach($user->id);

        $user->loadCount(['followers', 'following']);

        return response()->json([
            'message' => 'User followed successfully.',
            'user' => $this->publicProfilePayload($user, $viewer->fresh()),
        ], Response::HTTP_CREATED);
    }

    public function unfollow(Request $request, User $user): JsonResponse
    {
        $viewer = $request->user();

        $viewer->following()->detach($user->id);

        $user->loadCount(['followers', 'following']);

        return response()->json([
            'message' => 'User unfollowed successfully.',
            'user' => $this->publicProfilePayload($user, $viewer->fresh()),
        ]);
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit(User $user)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, User $user)
    {
        //
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(User $user)
    {
        //
    }

    public function currentUser(Request $request): JsonResponse
    {
        $user = $request->user();

        try {
            $user->loadCount(['followers', 'following']);
        } catch (\Throwable $e) {
            Log::warning('currentUser: follower counts unavailable', [
                'message' => $e->getMessage(),
            ]);
        }

        return response()->json([
            'id' => $user->id,
            'first_name' => $user->first_name,
            'last_name' => $user->last_name,
            'email' => $user->email,
            'profile_photo_url' => $this->fixMediaUrl($user->profile_photo_url ?? ''),
            'followers_count' => (int) ($user->followers_count ?? 0),
            'following_count' => (int) ($user->following_count ?? 0),
        ]);
    }

    private function publicProfilePayload(User $user, ?User $viewer = null): array
    {
        $payload = [
            'id' => $user->id,
            'name' => $user->name,
            'first_name' => $user->first_name ?? '',
            'last_name' => $user->last_name ?? '',
            'profile_photo_url' => $this->fixMediaUrl($user->profile_photo_url ?? ''),
            'followers_count' => $user->followers_count ?? $user->followers()->count(),
            'following_count' => $user->following_count ?? $user->following()->count(),
        ];

        if ($viewer !== null) {
            $payload['is_following'] = $viewer->following()
                ->where('users.id', $user->id)
                ->exists();
        }

        return $payload;
    }
}
