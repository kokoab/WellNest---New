<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\Post;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminDashboardController extends Controller
{
    /** Calendar months shown for the "monthly" chart range. */
    private const ANALYTICS_MONTHLY_COUNT = 6;

    /** Calendar days shown for the "weekly" chart range (inclusive of today). */
    private const ANALYTICS_WEEKLY_DAY_COUNT = 7;

    /** Calendar months shown for the "yearly" chart range. */
    private const ANALYTICS_YEARLY_MONTH_COUNT = 12;

    /** Equal-width buckets for the "all" range (covers long history in few points). */
    private const ANALYTICS_ALL_BUCKET_COUNT = 6;

    /**
     * Lower bound for the "all" analytics range (UTC), aligned with dummy seed history.
     */
    private const ANALYTICS_ALL_START_UTC = '2025-01-01 00:00:00';

    /**
     * Get user growth statistics for charts.
     * Returns bucketed signup counts so each point spans part of the selected range.
     */
    public function userGrowth(Request $request): JsonResponse
    {
        $range = (string) $request->query('range', 'monthly');
        [$start, $end] = $this->resolveAnalyticsWindow($range);

        $data = $this->analyticsBuckets(
            $range,
            User::query()->where('created_at', '<=', $end),
            $start,
            $end
        );

        return response()->json([
            'data' => $data,
            'range' => $range,
            'bucket_count' => count($data),
        ]);
    }

    /**
     * Get post frequency statistics for charts (bucketed).
     */
    public function postFrequency(Request $request): JsonResponse
    {
        $range = (string) $request->query('range', 'monthly');
        [$start, $end] = $this->resolveAnalyticsWindow($range);

        $data = $this->analyticsBuckets(
            $range,
            Post::query()->where('created_at', '<=', $end),
            $start,
            $end
        );

        return response()->json([
            'data' => $data,
            'range' => $range,
            'bucket_count' => count($data),
        ]);
    }

    /**
     * Get chatbot interaction statistics for charts (bucketed).
     */
    public function chatbotInteractions(Request $request): JsonResponse
    {
        $range = (string) $request->query('range', 'monthly');
        [$start, $end] = $this->resolveAnalyticsWindow($range);

        $data = $this->analyticsBuckets(
            $range,
            Conversation::query()->where('created_at', '<=', $end),
            $start,
            $end
        );

        return response()->json([
            'data' => $data,
            'range' => $range,
            'bucket_count' => count($data),
        ]);
    }

    /**
     * Get overview statistics for admin dashboard.
     */
    public function overview(Request $request): JsonResponse
    {
        $totalUsers = User::count();
        $totalPosts = Post::count();
        $totalConversations = Conversation::count();
        $activeUsers = User::where('status', 'active')->count();
        $inactiveUsers = User::where('status', 'inactive')->count();

        return response()->json([
            'total_users' => $totalUsers,
            'total_posts' => $totalPosts,
            'total_conversations' => $totalConversations,
            'active_users' => $activeUsers,
            'inactive_users' => $inactiveUsers,
        ]);
    }

    /**
     * @return array{0: Carbon, 1: Carbon}
     */
    private function resolveAnalyticsWindow(string $range): array
    {
        $now = Carbon::now('UTC');
        $end = $now->copy();

        return match ($range) {
            'weekly' => [$now->copy()->subDays(self::ANALYTICS_WEEKLY_DAY_COUNT - 1)->startOfDay(), $end],
            'monthly' => [$now->copy()->subDays(30)->startOfDay(), $end],
            'yearly' => [$now->copy()->subYear()->startOfDay(), $end],
            'all' => [Carbon::parse(self::ANALYTICS_ALL_START_UTC, 'UTC'), $end],
            default => [$now->copy()->subDays(30)->startOfDay(), $end],
        };
    }

    /**
     * @param  Builder<\Illuminate\Database\Eloquent\Model>  $query
     * @return list<array{date: string, count: int, label?: string}>
     */
    private function analyticsBuckets(string $range, Builder $query, Carbon $start, Carbon $end): array
    {
        return match ($range) {
            'weekly' => $this->calendarDayBuckets($query, $end, self::ANALYTICS_WEEKLY_DAY_COUNT),
            'monthly' => $this->calendarMonthBuckets($query, $end, self::ANALYTICS_MONTHLY_COUNT, false),
            'yearly' => $this->calendarMonthBuckets($query, $end, self::ANALYTICS_YEARLY_MONTH_COUNT, true),
            default => $this->bucketedCounts($query, $start, $end, self::ANALYTICS_ALL_BUCKET_COUNT),
        };
    }

    /**
     * Last N calendar days ending at {@see $periodEnd} (oldest → newest).
     *
     * @param  Builder<\Illuminate\Database\Eloquent\Model>  $query
     * @return list<array{date: string, label: string, count: int}>
     */
    private function calendarDayBuckets(Builder $query, Carbon $periodEnd, int $dayCount): array
    {
        $periodEnd = $periodEnd->copy()->utc();
        $out = [];

        for ($i = $dayCount - 1; $i >= 0; $i--) {
            $dayStart = $periodEnd->copy()->subDays($i)->startOfDay();
            $dayEnd = $dayStart->copy()->endOfDay();
            if ($dayEnd->greaterThan($periodEnd)) {
                $dayEnd = $periodEnd->copy();
            }

            $count = (clone $query)
                ->where('created_at', '>=', $dayStart)
                ->where('created_at', '<=', $dayEnd)
                ->count();

            $out[] = [
                'date' => $dayStart->toDateString(),
                'label' => $dayStart->format('D, M j'),
                'count' => $count,
            ];
        }

        return $out;
    }

    /**
     * Last N calendar months (oldest → newest), inclusive of partial current month.
     *
     * @param  Builder<\Illuminate\Database\Eloquent\Model>  $query
     * @return list<array{date: string, label: string, count: int}>
     */
    private function calendarMonthBuckets(Builder $query, Carbon $periodEnd, int $monthCount, bool $compactLabel): array
    {
        $periodEnd = $periodEnd->copy()->utc();
        $desc = [];
        $cursor = $periodEnd->copy()->startOfMonth();

        for ($i = 0; $i < $monthCount; $i++) {
            $from = $cursor->copy();
            $to = $cursor->copy()->endOfMonth();
            if ($to->greaterThan($periodEnd)) {
                $to = $periodEnd->copy();
            }
            $desc[] = [$from, $to];
            $cursor = $cursor->copy()->subMonth()->startOfMonth();
        }

        $chrono = array_reverse($desc);
        $out = [];

        foreach ($chrono as [$from, $to]) {
            $count = (clone $query)
                ->where('created_at', '>=', $from)
                ->where('created_at', '<=', $to)
                ->count();

            $label = $compactLabel
                ? $from->format('M \'y')
                : $from->format('F Y');

            $out[] = [
                'date' => $to->copy()->startOfDay()->toDateString(),
                'label' => $label,
                'count' => $count,
            ];
        }

        return $out;
    }

    /**
     * @param  Builder<\Illuminate\Database\Eloquent\Model>  $query
     * @return list<array{date: string, count: int}>
     */
    private function bucketedCounts(Builder $query, Carbon $start, Carbon $end, int $buckets): array
    {
        $start = $start->copy()->utc();
        $end = $end->copy()->utc();
        if ($end->lessThanOrEqualTo($start)) {
            return [];
        }

        $totalSeconds = max(1, $end->getTimestamp() - $start->getTimestamp());
        $out = [];

        for ($i = 0; $i < $buckets; $i++) {
            $from = $start->copy()->addSeconds((int) floor($totalSeconds * $i / $buckets));
            $to = $i === $buckets - 1
                ? $end
                : $start->copy()->addSeconds((int) floor($totalSeconds * ($i + 1) / $buckets));

            $count = (clone $query)
                ->where('created_at', '>=', $from)
                ->where('created_at', '<=', $to)
                ->count();

            $label = $to->copy()->startOfDay()->toDateString();

            $out[] = [
                'date' => $label,
                'count' => $count,
            ];
        }

        return $out;
    }
}
