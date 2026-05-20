<?php

namespace App\Support;

use App\Models\User;

/**
 * Stable API shape for authenticated user responses.
 * Admin access: `role === 'admin'` OR `is_admin === true` (both supported for compatibility).
 */
final class UserPayload
{
    public static function make(User $user): array
    {
        return [
            'id' => $user->id,
            'first_name' => $user->first_name,
            'last_name' => $user->last_name,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'is_admin' => (bool) $user->is_admin || ($user->role ?? '') === 'admin',
            'profile_photo_url' => MediaUrlHelper::fixLocalDevPort($user->profile_photo_url ?? ''),
            'account_status' => $user->account_status ?? 'active',
            'created_at' => $user->created_at?->toIso8601String(),
            'updated_at' => $user->updated_at?->toIso8601String(),
        ];
    }
}
