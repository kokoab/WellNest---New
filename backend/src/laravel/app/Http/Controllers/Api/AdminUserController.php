<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Services\ActivityLogService;
use Carbon\Carbon;

class AdminUserController extends Controller
{
    /**
     * List all users. Requires authenticated admin.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user || ! $user->is_admin) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $range = $request->query('range');
        $search = trim((string) $request->query('search', ''));

        $usersQuery = User::query()
            ->orderBy('created_at', 'desc');

        $hasCustomRange = $request->filled('start_date') || $request->filled('end_date');
        if ($hasCustomRange) {
            if ($request->filled('start_date')) {
                $usersQuery->where('created_at', '>=', Carbon::parse($request->start_date)->startOfDay());
            }
            if ($request->filled('end_date')) {
                $usersQuery->where('created_at', '<=', Carbon::parse($request->end_date)->endOfDay());
            }
        } elseif ($search === '') {
            $startDate = $this->resolveStartDate($range);
            if ($startDate !== null) {
                $usersQuery->where('created_at', '>=', $startDate);
            }
        }

        if ($search !== '') {
            $usersQuery->where(function ($query) use ($search) {
                $like = '%' . addcslashes($search, '%_\\') . '%';
                $query->where('first_name', 'like', $like)
                    ->orWhere('last_name', 'like', $like)
                    ->orWhere('email', 'like', $like)
                    ->orWhereRaw("CONCAT_WS(' ', first_name, last_name) LIKE ?", [$like]);
            });
        }

        $perPage = max(1, min(100, (int) $request->query('per_page', 10)));
        $page = max(1, (int) $request->query('page', 1));

        // Active rows matching the same filters (group OR so date range still applies).
        $activeCount = (clone $usersQuery)->where(function ($q) {
            $q->where('account_status', 'active')->orWhereNull('account_status');
        })->count();

        $paginator = $usersQuery->paginate($perPage, ['*'], 'page', $page);

        $users = $paginator->getCollection()->map(fn(User $u) => [
            'id' => $u->id,
            'name' => $u->name,
            'email' => $u->email,
            'status' => $u->account_status ?? 'active',
            'account_status' => $u->account_status ?? 'active',
            'created_at' => $u->created_at?->toIso8601String(),
        ]);

        return response()->json([
            'data' => $users,
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
                'active_total' => $activeCount,
            ],
            'links' => [
                'next' => $paginator->nextPageUrl(),
                'prev' => $paginator->previousPageUrl(),
            ],
        ]);
    }

    /**
     * Update user status (active/inactive). Requires authenticated admin.
     */
    public function updateStatus(Request $request, User $user): JsonResponse
    {
        $admin = $request->user();
        if (! $admin || ! $admin->is_admin) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }
        if ($user->id === $admin->id) {
            return response()->json(['message' => 'You cannot deactivate your own account'], 400);
        }

        $validated = $request->validate([
            'account_status' => 'required_without:status|in:active,suspended',
            'status' => 'required_without:account_status|in:active,suspended',
        ]);

        $newStatus = $validated['account_status'] ?? $validated['status'];

        $user->account_status = $newStatus;
        $user->save();

        if ($user->account_status === 'suspended') {
            $user->tokens()->delete();
        }

        ActivityLogService::log('admin_user', 'update_status', 'User status updated.', $admin->id, $user);
        return response()->json([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'status' => $user->account_status,
            'account_status' => $user->account_status,
        ]);
    }

    /**
     * Delete a user. Requires authenticated admin.
     */
    public function destroy(Request $request, User $user): JsonResponse
    {
        $hasRecipes = $user->recipes()->exists();
        $hasPosts = $user->posts()->exists();
        $hasComments = $user->comments()->exists();

        if ($hasRecipes || $hasPosts || $hasComments) {
            return response()->json([
                'message' => 'Cannot delete user with existing contributions. Please migrate or delete their data first.',
            ], 403);
        }

        if ($user->id === $request->user()->id) {
            return response()->json(['message' => 'You cannot delete your own account'], 403);
        }

        $user->delete();

        ActivityLogService::log('admin_user', 'delete_user', 'User deleted.', $request->user()->id, $user);
        return response()->json(null, 204);
    }

    private function resolveStartDate(?string $range): ?Carbon
    {
        return match ($range) {
            'weekly' => now()->subWeek(),
            'monthly' => now()->subMonth(),
            'yearly' => now()->subYear(),
            'all' => null,
            default => null,
        };
    }
}
