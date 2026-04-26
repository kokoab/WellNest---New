<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    private const CATEGORY_MESSAGE = 'MESSAGE_TYPE';
    private const CATEGORY_ACTIVITY = 'ACTIVITY_TYPE';
    private const MESSAGE_SUBTYPES = ['new_message'];

    /**
     * List the authenticated user's notifications.
     * Optional filter: ?category=MESSAGE_TYPE|ACTIVITY_TYPE
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $perPage = min((int) $request->get('per_page', 15), 50);
        $unreadOnly = filter_var($request->get('unread_only', false), FILTER_VALIDATE_BOOLEAN);
        $category = strtoupper((string) $request->get('category', ''));

        if ($category !== '' && ! in_array($category, [self::CATEGORY_MESSAGE, self::CATEGORY_ACTIVITY], true)) {
            return response()->json(['message' => 'Invalid category'], 422);
        }

        $query = $user->notifications();

        if ($unreadOnly) {
            $query->whereNull('read_at');
        }

        if ($category !== '') {
            $this->applyCategoryFilter($query, $category);
        }

        $notifications = $query->orderBy('created_at', 'desc')->paginate($perPage);

        $data = $notifications->getCollection()->map(function ($notification) {
            $data = $notification->data ?? [];

            return [
                'id' => $notification->id,
                'type' => $data['type'] ?? 'unknown',
                'category' => $this->resolveCategory($data),
                'message' => $data['message'] ?? '',
                'data' => $data,
                'read_at' => $notification->read_at?->toIso8601String(),
                'created_at' => $notification->created_at->toIso8601String(),
            ];
        });

        $counts = $this->unreadCounts($request);

        return response()->json([
            'data' => $data,
            'current_page' => $notifications->currentPage(),
            'last_page' => $notifications->lastPage(),
            'total' => $notifications->total(),
            'counts' => $counts,
        ]);
    }

    /**
     * Mark a notification as read.
     */
    public function markAsRead(Request $request, string $id): JsonResponse
    {
        $notification = $request->user()->notifications()->findOrFail($id);
        $notification->markAsRead();

        return response()->json(['message' => 'Notification marked as read']);
    }

    /**
     * Mark all notifications as read.
     */
    public function markAllAsRead(Request $request): JsonResponse
    {
        $request->user()->unreadNotifications->markAsRead();

        return response()->json(['message' => 'All notifications marked as read']);
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $counts = $this->unreadCounts($request);
        $category = strtoupper((string) $request->get('category', ''));

        $count = match ($category) {
            self::CATEGORY_MESSAGE => $counts['message_unread'],
            self::CATEGORY_ACTIVITY => $counts['activity_unread'],
            default => $counts['all_unread'],
        };

        return response()->json([
            'count' => $count,
            'counts' => $counts,
        ]);
    }

    private function unreadCounts(Request $request): array
    {
        $user = $request->user();

        $messageUnread = $user->unreadNotifications()
            ->whereIn('data->type', self::MESSAGE_SUBTYPES)
            ->count();

        $activityUnread = $user->unreadNotifications()
            ->where(function (Builder $q) {
                $q->whereNotIn('data->type', self::MESSAGE_SUBTYPES)
                    ->orWhereNull('data->type');
            })
            ->count();

        return [
            'all_unread' => $messageUnread + $activityUnread,
            'message_unread' => $messageUnread,
            'activity_unread' => $activityUnread,
            self::CATEGORY_MESSAGE => $messageUnread,
            self::CATEGORY_ACTIVITY => $activityUnread,
        ];
    }

    private function applyCategoryFilter(Builder $query, string $category): void
    {
        if ($category === self::CATEGORY_MESSAGE) {
            $query->whereIn('data->type', self::MESSAGE_SUBTYPES);
            return;
        }

        $query->where(function (Builder $q) {
            $q->whereNotIn('data->type', self::MESSAGE_SUBTYPES)
                ->orWhereNull('data->type');
        });
    }

    private function resolveCategory(array $data): string
    {
        $type = (string) ($data['type'] ?? '');

        return in_array($type, self::MESSAGE_SUBTYPES, true)
            ? self::CATEGORY_MESSAGE
            : self::CATEGORY_ACTIVITY;
    }
}
