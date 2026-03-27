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

        $usersQuery = User::query()
            ->orderBy('created_at', 'desc');

        $startDate = $this->resolveStartDate($range);
        if ($startDate !== null) {
            $usersQuery->where('created_at', '>=', $startDate);
        }

        $users = $usersQuery
            ->get()
            ->map(fn(User $u) => [
                'id' => $u->id,
                'name' => $u->name,
                'email' => $u->email,
                'status' => $u->status ?? 'active',
                'created_at' => $u->created_at,
            ]);

        return response()->json($users);
    }

    /**
     * Update user status (active/inactive). Requires authenticated admin.
     */
    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $admin = $request->user();
        if (! $admin || ! $admin->is_admin) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $request->validate([
            'status' => 'required|in:active,inactive,suspended',
        ]);

        $user = User::find($id);
        if (! $user) {
            return response()->json(['message' => 'User not found'], 404);
        }

        if ($user->id === $admin->id) {
            return response()->json(['message' => 'You cannot deactivate your own account'], 400);
        }

        $user->status = $request->status;
        $user->save();

        ActivityLogService::log('admin_user', 'update_status', 'User status updated.', $admin->id, $user);
        return response()->json([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'status' => $user->status,
        ]);
    }

    /**
     * Delete a user. Requires authenticated admin.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $admin = $request->user();
        if (! $admin || ! $admin->is_admin) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $user = User::find($id);
        if (! $user) {
            return response()->json(['message' => 'User not found'], 404);
        }

        if ($user->id === $admin->id) {
            return response()->json(['message' => 'You cannot delete your own account'], 400);
        }

        $user->delete();

        ActivityLogService::log('admin_user', 'delete_user', 'User deleted.', $admin->id, $user);
        return response()->json(null, 204);
    }

    private function resolveStartDate(?string $range): ?Carbon
    {
        return match ($range) {
            'weekly' => now()->subWeek(),
            'monthly' => now()->subMonth(),
            'yearly' => now()->subYear(),
            default => null,
        };
    }
}
