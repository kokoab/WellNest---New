<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Support\Assistant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

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
        //
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
}
