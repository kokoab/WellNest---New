<?php

namespace App\Support;

final class AssistantReplyRecipeParser
{
    /**
     * Split assistant raw output into display text and recipe ids from a trailing "RECIPES: 1,2,3" line.
     *
     * @return array{0: string, 1: array<int, int>}
     */
    public static function splitContentAndRecipeIds(string $raw): array
    {
        $raw = trim($raw);
        // Prefer newline before RECIPES; some models append " RECIPES: 1,2" on the last sentence line.
        $pattern = '/(?:^|\n|\s)RECIPES:\s*([\d,\s]*)\s*$/i';

        if (preg_match($pattern, $raw, $m)) {
            $ids = [];
            foreach (preg_split('/[\s,]+/', trim((string) $m[1]), -1, PREG_SPLIT_NO_EMPTY) as $part) {
                if (ctype_digit((string) $part)) {
                    $ids[] = (int) $part;
                }
            }
            $content = trim((string) preg_replace($pattern, '', $raw));

            return [$content, $ids];
        }

        return [$raw, []];
    }
}
