<?php

namespace App\Support;

use App\Models\User;

final class Assistant
{
    private static ?int $cachedUserId = null;

    public static function botUserId(): ?int
    {
        if (self::$cachedUserId !== null) {
            return self::$cachedUserId;
        }
        $fromEnv = config('assistant.bot_user_id');
        if ($fromEnv !== null && $fromEnv !== '') {
            return self::$cachedUserId = (int) $fromEnv;
        }
        $email = config('assistant.bot_email');
        if (! $email) {
            return null;
        }

        return self::$cachedUserId = User::where('email', $email)->value('id');
    }

    public static function isConversationWithAssistant(int $user1Id, int $user2Id): bool
    {
        $botId = self::botUserId();
        if (! $botId) {
            return false;
        }

        return $user1Id === $botId || $user2Id === $botId;
    }
}
