<?php

namespace App\Services;

use App\Models\Recipe;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class AssistantRecipeCatalogService
{
    /**
     * @return array{catalog: Collection<int, Recipe>, food_related: bool, intent: string}
     */
    public function resolveCatalogForAssistant(string $userMessage): array
    {
        $term = trim($userMessage);
        if ($term === '') {
            return ['catalog' => collect(), 'food_related' => false, 'intent' => 'general'];
        }

        $rankingMode = $this->rankingMode($term);
        if ($rankingMode !== null) {
            return [
                'catalog' => $this->rankedRecipes($rankingMode),
                'food_related' => true,
                'intent' => 'ranking:'.$rankingMode,
            ];
        }

        $primary = $this->searchRecipes($term);
        $foodRelated = $this->looksFoodRelated($term) || $primary->isNotEmpty();

        if ($primary->isNotEmpty()) {
            return ['catalog' => $primary, 'food_related' => true, 'intent' => 'search'];
        }

        if ($foodRelated && config('assistant.recipe_catalog_fallback_recent', true)) {
            return ['catalog' => $this->recentRecipes(), 'food_related' => true, 'intent' => 'recent'];
        }

        return ['catalog' => collect(), 'food_related' => $foodRelated, 'intent' => 'general'];
    }

    public function looksFoodRelated(string $message): bool
    {
        $lower = strtolower($message);
        $keywords = config('assistant.food_intent_keywords', []);
        if (! is_array($keywords)) {
            return false;
        }
        foreach ($keywords as $kw) {
            if (! is_string($kw) || $kw === '') {
                continue;
            }
            if (str_contains($lower, strtolower($kw))) {
                return true;
            }
        }

        return false;
    }

    /**
     * @return Collection<int, Recipe>
     */
    private function searchRecipes(string $term): Collection
    {
        $limit = max(1, min(50, (int) config('assistant.recipe_catalog_limit', 24)));

        $query = Recipe::query()
            ->select(['id', 'title'])
            ->orderByDesc('created_at');

        $query->where(function ($q) use ($term) {
            $q->where('title', 'like', '%'.$term.'%')
                ->orWhereHas('ingredients', function ($q2) use ($term) {
                    $q2->where('name', 'like', '%'.$term.'%');
                })
                ->orWhereHas('user', function ($q3) use ($term) {
                    $q3->whereRaw("CONCAT(first_name, ' ', last_name) LIKE ?", ['%'.$term.'%'])
                        ->orWhere('first_name', 'like', '%'.$term.'%')
                        ->orWhere('last_name', 'like', '%'.$term.'%');
                });
        });

        return $query->limit($limit)->get();
    }

    private function rankingMode(string $message): ?string
    {
        $lower = strtolower($message);

        if (str_contains($lower, 'top rated') || str_contains($lower, 'highest rated')) {
            return 'ratings';
        }

        if (
            str_contains($lower, 'popular')
            || str_contains($lower, 'most viewed')
            || str_contains($lower, 'trending')
        ) {
            return 'views';
        }

        if (
            str_contains($lower, 'top ranked')
            || str_contains($lower, 'ranking')
            || str_contains($lower, 'ranked recipes')
            || str_contains($lower, 'best recipes')
        ) {
            return 'combined';
        }

        return null;
    }

    /**
     * Same ranking math as RecipeRankingController's default 7-day leaderboard.
     *
     * @return Collection<int, Recipe>
     */
    private function rankedRecipes(string $mode): Collection
    {
        $limit = max(1, min(50, (int) config('assistant.recipe_catalog_limit', 24)));
        $fromDate = Carbon::now()->subDays(7)->toDateString();

        $recipes = Recipe::query()
            ->select(['id', 'title'])
            ->withAvg('ratings as average_rating', 'rating')
            ->withCount('ratings')
            ->withCount(['views as views_count' => function ($query) use ($fromDate) {
                $query->where('view_date', '>=', $fromDate);
            }])
            ->get();

        $maxViews = max(1, (int) $recipes->max('views_count'));

        return $recipes
            ->map(function (Recipe $recipe) use ($maxViews) {
                $avg = (float) ($recipe->average_rating ?? 0);
                $views = (int) ($recipe->views_count ?? 0);
                $recipe->ranking_score = (0.6 * min(1, $avg / 5.0)) + (0.4 * min(1, $views / $maxViews));

                return $recipe;
            })
            ->filter(fn (Recipe $recipe) => (int) $recipe->views_count > 0 || (int) $recipe->ratings_count > 0)
            ->sortByDesc(match ($mode) {
                'views' => 'views_count',
                'ratings' => 'average_rating',
                default => 'ranking_score',
            })
            ->values()
            ->take($limit);
    }

    /**
     * @return Collection<int, Recipe>
     */
    private function recentRecipes(): Collection
    {
        $limit = max(1, min(50, (int) config('assistant.recipe_catalog_fallback_limit', 15)));

        return Recipe::query()
            ->select(['id', 'title'])
            ->orderByDesc('created_at')
            ->limit($limit)
            ->get();
    }
}
