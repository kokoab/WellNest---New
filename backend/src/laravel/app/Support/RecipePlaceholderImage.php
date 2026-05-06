<?php

namespace App\Support;

use App\Models\Recipe;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Creates a simple SVG placeholder on the public disk and attaches it to the recipe.
 */
class RecipePlaceholderImage
{
    public static function ensureForRecipe(Recipe $recipe): bool
    {
        if ($recipe->images()->exists()) {
            return false;
        }

        $filePath = 'recipes/placeholder-'.$recipe->id.'.svg';
        $bg = sprintf('#%06X', random_int(0x303030, 0xE0E0E0));
        $title = htmlspecialchars(Str::limit($recipe->title, 72), ENT_QUOTES | ENT_XML1, 'UTF-8');

        $svg = <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="800" viewBox="0 0 1200 800">
  <rect width="1200" height="800" fill="{$bg}"/>
  <rect x="80" y="80" width="1040" height="640" rx="24" fill="#ffffff" fill-opacity="0.92"/>
  <text x="600" y="380" text-anchor="middle" font-family="system-ui,Segoe UI,Arial,sans-serif" font-size="52" fill="#1f2937">{$title}</text>
  <text x="600" y="450" text-anchor="middle" font-family="system-ui,Segoe UI,Arial,sans-serif" font-size="28" fill="#6b7280">WellNest</text>
</svg>
SVG;

        Storage::disk('public')->put($filePath, $svg);
        $recipe->images()->create(['path' => $filePath]);

        return true;
    }
}
