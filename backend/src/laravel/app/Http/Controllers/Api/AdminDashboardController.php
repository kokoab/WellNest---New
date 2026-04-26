<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Post;
use App\Models\Conversation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Carbon\Carbon;

class AdminDashboardController extends Controller
{
    /**
     * Get user growth statistics for charts.
     * Returns daily user signup counts for the specified range.
     */
    public function userGrowth(Request $request): JsonResponse
    {
        $range = $request->query('range', 'monthly');
        $startDate = $this->resolveStartDate($range);
        
        $users = User::where('created_at', '>=', $startDate)
            ->selectRaw('DATE(created_at) as date, COUNT(*) as count')
            ->groupBy('date')
            ->orderBy('date')
            ->get();
        
        return response()->json([
            'data' => $users->map(fn($u) => [
                'date' => $u->date,
                'count' => $u->count,
            ]),
            'range' => $range,
        ]);
    }

    /**
     * Get post frequency statistics for charts.
     * Returns daily post creation counts for the specified range.
     */
    public function postFrequency(Request $request): JsonResponse
    {
        $range = $request->query('range', 'monthly');
        $startDate = $this->resolveStartDate($range);
        
        $posts = Post::where('created_at', '>=', $startDate)
            ->selectRaw('DATE(created_at) as date, COUNT(*) as count')
            ->groupBy('date')
            ->orderBy('date')
            ->get();
        
        return response()->json([
            'data' => $posts->map(fn($p) => [
                'date' => $p->date,
                'count' => $p->count,
            ]),
            'range' => $range,
        ]);
    }

    /**
     * Get chatbot interaction statistics for charts.
     * Returns daily chatbot message counts for the specified range.
     * Assumes chatbot interactions are tracked via conversations with a bot user.
     */
    public function chatbotInteractions(Request $request): JsonResponse
    {
        $range = $request->query('range', 'monthly');
        $startDate = $this->resolveStartDate($range);
        
        // Count conversations created per day (chatbot interactions)
        $conversations = Conversation::where('created_at', '>=', $startDate)
            ->selectRaw('DATE(created_at) as date, COUNT(*) as count')
            ->groupBy('date')
            ->orderBy('date')
            ->get();
        
        return response()->json([
            'data' => $conversations->map(fn($c) => [
                'date' => $c->date,
                'count' => $c->count,
            ]),
            'range' => $range,
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
     * Resolve start date from range parameter.
     */
    private function resolveStartDate(string $range): Carbon
    {
        return match ($range) {
            'weekly' => Carbon::now()->subWeek(),
            'monthly' => Carbon::now()->subMonth(),
            'yearly' => Carbon::now()->subYear(),
            default => Carbon::now()->subMonth(),
        };
    }
}