<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Recipe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class RecipeRankingController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $window = (string) $request->get('window', '7d');
        $mode = (string) $request->get('mode', 'combined');

        $fromDate = match ($window) {
            '7d' => Carbon::now()->subDays(7)->toDateString(),
            '30d' => Carbon::now()->subDays(30)->toDateString(),
            'all' => null,
            default => Carbon::now()->subDays(7)->toDateString(),
        };

        $baseUrl = rtrim(config('app.url'), '/');

        $recipes = Recipe::query()
            ->with([
                'category:id,name',
                'images:id,path,imageable_id,imageable_type',
                'user:id,first_name,last_name,email',
            ])
            ->withAvg('ratings as average_rating', 'rating')
            ->withCount('ratings')
            ->withCount(['views as views_count' => function ($query) use ($fromDate) {
                if ($fromDate !== null) {
                    $query->where('view_date', '>=', $fromDate);
                }
            }])
            ->get();

        $maxViews = max(1, (int) $recipes->max('views_count'));

        $ranked = $recipes->map(function ($r) use ($maxViews, $baseUrl) {
            $avg = (float) ($r->average_rating ?? 0);
            $views = (int) ($r->views_count ?? 0);
            $ratingNorm = min(1, $avg / 5.0);
            $viewsNorm = min(1, $views / $maxViews);
            $score = (0.6 * $ratingNorm) + (0.4 * $viewsNorm);

            $firstImage = $r->images->first();
            $authorName = trim(($r->user?->first_name ?? '') . ' ' . ($r->user?->last_name ?? ''));
            if ($authorName === '') {
                $authorName = $r->user?->email ?? null;
            }

            return [
                'id' => $r->id,
                'title' => $r->title,
                'image_url' => $firstImage ? $baseUrl . '/storage/' . $firstImage->path : null,
                'author_name' => $authorName,
                'category' => $r->category?->name,
                'prep_time' => (int) $r->prep_time,
                'average_rating' => round($avg, 2),
                'ratings_count' => (int) $r->ratings_count,
                'views_count' => $views,
                'score' => round($score, 4),
            ];
        });

        $sorted = match ($mode) {
            'views' => $ranked->sortByDesc('views_count')->values(),
            'ratings' => $ranked->sortByDesc('average_rating')->values(),
            default => $ranked->sortByDesc('score')->values(),
        };

        $sorted = $sorted
            ->filter(fn ($x) => $x['views_count'] > 0 || $x['ratings_count'] > 0)
            ->values();

        return response()->json(['data' => $sorted], 200);
    }
}
