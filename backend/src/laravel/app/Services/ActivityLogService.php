<?php

namespace App\Services;

use App\Models\ActivityLog;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;

class ActivityLogService
{
    public static function log(
        string $category,
        string $action,
        string $description,
        ?int $userId = null,
        ?Model $subject = null,
        array $extra = []
    ): void {
        $data = [
            'user_id' => $userId,
            'category' => $category,
            'action' => $action,
            'description' => $description,
        ];

        if ($subject) {
            $data['subject_type'] = get_class($subject);
            $data['subject_id'] = $subject->getKey();
        }

        $data = array_merge($data, $extra);
        ActivityLog::create($data);
    }

    public static function logFromRequest(Request $request, ...$args): void
    {
        $extra = ['ip' => $request->ip()];
        $data = array_merge($args, [array_merge($extra, $args[4] ?? [])]);
        if (isset($data[4]) && is_array($data[4])) {
            $extra = array_merge($extra, $data[4]);
        }
        self::log($data[0], $data[1], $data[2], $data[3] ?? null, $data[4] ?? null, $extra);
    }
}
