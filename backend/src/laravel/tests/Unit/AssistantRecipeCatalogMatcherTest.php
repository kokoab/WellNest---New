<?php

namespace Tests\Unit;

use App\Models\Recipe;
use App\Support\AssistantRecipeCatalogMatcher;
use Illuminate\Support\Collection;
use PHPUnit\Framework\TestCase;

class AssistantRecipeCatalogMatcherTest extends TestCase
{
    public function test_supplements_when_titles_appear_in_text(): void
    {
        $a = new Recipe;
        $a->forceFill(['id' => 1, 'title' => 'Buffalo Chicken Lettuce Wraps']);
        $b = new Recipe;
        $b->forceFill(['id' => 2, 'title' => 'Tuna Poke Bowl']);
        $catalog = new Collection([$a, $b]);

        $text = 'Consider Buffalo Chicken Lettuce Wraps or the Tuna Poke Bowl from our catalog.';

        $out = AssistantRecipeCatalogMatcher::supplementFromTitleMatches($text, $catalog, [], 5);

        $this->assertCount(2, $out);
        $this->assertSame(1, $out[0]['id']);
        $this->assertSame(2, $out[1]['id']);
    }

    public function test_preserves_existing_ids_and_dedupes(): void
    {
        $a = new Recipe;
        $a->forceFill(['id' => 1, 'title' => 'Buffalo Chicken Lettuce Wraps']);
        $b = new Recipe;
        $b->forceFill(['id' => 2, 'title' => 'Tuna Poke Bowl']);
        $catalog = new Collection([$a, $b]);

        $existing = [['id' => 1, 'title' => 'Buffalo Chicken Lettuce Wraps']];
        $text = 'Also try the Tuna Poke Bowl.';

        $out = AssistantRecipeCatalogMatcher::supplementFromTitleMatches($text, $catalog, $existing, 5);

        $this->assertCount(2, $out);
        $this->assertSame(1, $out[0]['id']);
        $this->assertSame(2, $out[1]['id']);
    }
}
