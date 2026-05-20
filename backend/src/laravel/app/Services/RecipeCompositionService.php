<?php

namespace App\Services;

use App\Models\Ingredient;
use App\Models\Recipe;
use App\Models\RecipeStep;
use Illuminate\Support\Facades\Storage;

class RecipeCompositionService
{
    public function syncIngredients(Recipe $recipe, array $ingredientsData): void
    {
        $recipe->ingredients()->detach();
        foreach ($ingredientsData as $item) {
            $name = trim($item['name'] ?? '');
            if ($name === '') {
                continue;
            }
            $ingredient = Ingredient::firstOrCreate(['name' => $name]);
            $quantity = (int) round((float) ($item['quantity'] ?? 0));
            if ($quantity < 1) {
                $quantity = 1;
            }
            $unit = trim($item['unit'] ?? '') ?: 'unit';
            $recipe->ingredients()->attach($ingredient->id, [
                'quantity' => $quantity,
                'unit' => $unit,
            ]);
        }
    }

    public function syncSteps(Recipe $recipe, array $stepsPayload): void
    {
        $keepIds = [];
        foreach ($stepsPayload as $row) {
            if (! empty($row['id'])) {
                $keepIds[] = (int) $row['id'];
            }
        }

        $existingIds = $recipe->steps()->pluck('id')->map(fn ($id) => (int) $id)->all();
        $toDelete = array_diff($existingIds, $keepIds);
        foreach ($recipe->steps()->whereIn('id', $toDelete)->get() as $step) {
            $this->deleteStepImages($step);
            $step->delete();
        }

        foreach ($stepsPayload as $index => $row) {
            $title = isset($row['title']) ? trim((string) $row['title']) : '';
            $title = $title === '' ? null : $title;
            $instr = isset($row['instructions']) ? trim((string) $row['instructions']) : '';
            $instr = $instr === '' ? null : $instr;
            $prepMin = array_key_exists('prep_time_minutes', $row) && $row['prep_time_minutes'] !== null
                ? (int) $row['prep_time_minutes']
                : null;

            $attrs = [
                'sort_order' => $index,
                'title' => $title,
                'instructions' => $instr,
                'prep_time_minutes' => $prepMin,
            ];

            if (! empty($row['id'])) {
                $step = RecipeStep::where('recipe_id', $recipe->id)->where('id', (int) $row['id'])->first();
                if ($step) {
                    $step->update($attrs);

                    continue;
                }
            }
            $recipe->steps()->create($attrs);
        }
    }

    public function purgeRecipeSteps(Recipe $recipe): void
    {
        $recipe->load('steps.images');
        foreach ($recipe->steps as $step) {
            $this->deleteStepImages($step);
            $step->delete();
        }
    }

    public function deleteStepImages(RecipeStep $step): void
    {
        foreach ($step->images as $image) {
            Storage::disk('public')->delete($image->path);
            $image->delete();
        }
    }

    /**
     * @param  array<int, array<string, mixed>>  $steps
     */
    public function flattenStepsToInstructionsText(array $steps): string
    {
        $parts = [];
        foreach ($steps as $i => $s) {
            $title = isset($s['title']) ? trim((string) $s['title']) : '';
            $inst = isset($s['instructions']) ? trim((string) $s['instructions']) : '';
            $n = $i + 1;
            if ($title !== '' && $inst !== '') {
                $parts[] = "Step {$n}: {$title}\n{$inst}";
            } elseif ($title !== '') {
                $parts[] = "Step {$n}: {$title}";
            } elseif ($inst !== '') {
                $parts[] = "Step {$n}\n{$inst}";
            }
        }

        return implode("\n\n", $parts);
    }

    /**
     * @param  array<int, array<string, mixed>>  $steps
     */
    public function sumStepPrepMinutes(array $steps): int
    {
        $sum = 0;
        foreach ($steps as $s) {
            if (isset($s['prep_time_minutes']) && $s['prep_time_minutes'] !== null) {
                $sum += (int) $s['prep_time_minutes'];
            }
        }

        return $sum;
    }
}
