<?php

namespace App\Http\Controllers\Api\Activity;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Carbon\Carbon;

class LogController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $range = $request->query('range');

        $query = ActivityLog::with('user:id,first_name,last_name')
            ->orderBy('created_at', 'desc');

        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }
        if ($request->filled('action')) {
            $query->where('action', $request->action);
        }
        $startDate = $this->resolveStartDate($range);
        if ($startDate !== null) {
            $query->where('created_at', '>=', $startDate);
        }

        $logs = $query->paginate(50);

        return response()->json($logs);
    }

    public function exportCsv(Request $request): StreamedResponse
    {
        $category = $request->get('category', 'all');
        $range = $request->query('range');

        $query = ActivityLog::with('user:id,first_name,last_name')
            ->orderBy('created_at', 'desc');

        if ($category !== 'all') {
            $query->where('category', $category);
        }
        $startDate = $this->resolveStartDate($range);
        if ($startDate !== null) {
            $query->where('created_at', '>=', $startDate);
        }

        $filename = $category === 'all'
            ? 'activity_logs_all.csv'
            : "activity_logs_{$category}.csv";

        $headers = [
            'Content-Type' => 'text/csv',
            'Content-Disposition' => "attachment; filename=\"{$filename}\"",
        ];

        return response()->streamDownload(function () use ($query) {
            $handle = fopen('php://output', 'w');
            fputcsv($handle, ['id', 'created_at', 'category', 'action', 'description', 'actor', 'subject_type', 'subject_id', 'login_type', 'email', 'ip_address']);

            $query->chunk(500, function ($logs) use ($handle) {
                foreach ($logs as $log) {
                    fputcsv($handle, [
                        $log->id,
                        $log->created_at,
                        $log->category,
                        $log->action,
                        $log->description,
                        $log->user ? $log->user->name : null,
                        $log->subject_type,
                        $log->subject_id,
                        $log->login_type,
                        $log->email,
                        $log->ip_address,
                    ]);
                }
            });

            fclose($handle);
        }, $filename, $headers);
    }

    private function resolveStartDate(?string $range): ?Carbon
    {
        return match ($range) {
            'weekly' => now()->subWeek(),
            'monthly' => now()->subMonth(),
            'yearly' => now()->subYear(),
            default => null,
        };
    }
}
