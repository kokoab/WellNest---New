<?php

namespace App\Support;

use App\Models\Recipe;
use Illuminate\Support\Collection;

final class AssistantRecipeCatalogMatcher
{
    /**
     * Find catalog recipes whose titles appear in the assistant's visible reply so we can still
     * attach deep links when the model skips the RECIPES: machine line.
     *
     * @param  Collection<int, Recipe>  $catalog
     * @param  array<int, array{id: int, title: string}>  $existing
     * @return array<int, array{id: int, title: string}>
     */
    public static function supplementFromTitleMatches(
        string $visibleText,
        Collection $catalog,
        array $existing,
        int $maxTotal = 5,
    ): array {
        $visibleText = trim($visibleText);
        if ($visibleText === '' || $catalog->isEmpty()) {
            return $existing;
        }

        $lower = mb_strtolower($visibleText);
        $seen = [];
        foreach ($existing as $row) {
            $seen[(int) $row['id']] = true;
        }

        $hits = [];
        foreach ($catalog as $recipe) {
            $id = (int) $recipe->id;
            if (isset($seen[$id])) {
                continue;
            }
            $title = trim((string) $recipe->title);
            if ($title === '') {
                continue;
            }
            if (! self::titleAppearsInLowerContent($title, $lower)) {
                continue;
            }
            $pos = mb_stripos($visibleText, $title);
            $hits[] = [
                'id' => $id,
                'title' => $recipe->title,
                'pos' => $pos === false ? PHP_INT_MAX : $pos,
            ];
        }

        usort($hits, static fn (array $a, array $b): int => $a['pos'] <=> $b['pos']);

        $out = $existing;
        foreach ($hits as $h) {
            if (count($out) >= max(1, $maxTotal)) {
                break;
            }
            $out[] = [
                'id' => $h['id'],
                'title' => $h['title'],
            ];
            $seen[$h['id']] = true;
        }

        return $out;
    }

    private static function titleAppearsInLowerContent(string $title, string $contentLower): bool
    {
        $needle = mb_strtolower(trim($title));
        $len = mb_strlen($needle);
        if ($len < 4) {
            return false;
        }

        if ($len >= 10) {
            return str_contains($contentLower, $needle);
        }

        // Avoid noisy hits on very short titles (e.g. "Soup").
        return (bool) preg_match(
            '/(^|[\s,.;:!?()[\]"\x{201c}\x{201d}]|-)'.preg_quote($needle, '/').'($|[\s,.;:!?()[\]"\'-])/u',
            $contentLower,
        );
    }
}
