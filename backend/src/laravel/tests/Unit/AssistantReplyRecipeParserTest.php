<?php

namespace Tests\Unit;

use App\Support\AssistantReplyRecipeParser;
use PHPUnit\Framework\TestCase;

class AssistantReplyRecipeParserTest extends TestCase
{
    public function test_splits_trailing_recipes_line(): void
    {
        [$text, $ids] = AssistantReplyRecipeParser::splitContentAndRecipeIds(
            "Try these options.\nRECIPES: 12, 34 , 56"
        );

        $this->assertSame('Try these options.', $text);
        $this->assertSame([12, 34, 56], $ids);
    }

    public function test_empty_when_no_marker(): void
    {
        [$text, $ids] = AssistantReplyRecipeParser::splitContentAndRecipeIds('Just wellness tips.');

        $this->assertSame('Just wellness tips.', $text);
        $this->assertSame([], $ids);
    }

    public function test_inline_recipes_without_leading_newline(): void
    {
        [$text, $ids] = AssistantReplyRecipeParser::splitContentAndRecipeIds(
            'Try the Bowl. RECIPES: 9, 10'
        );

        $this->assertSame('Try the Bowl.', trim($text));
        $this->assertSame([9, 10], $ids);
    }
}
