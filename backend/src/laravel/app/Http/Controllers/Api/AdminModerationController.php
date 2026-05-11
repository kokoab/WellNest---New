<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;
use App\Models\Recipe;
use App\Models\Report;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use App\Services\ActivityLogService;
use Carbon\Carbon;

class AdminModerationController extends Controller
{
    /**
     * Admin review queue: list all pending reports (accounts, recipes, posts).
     */
    public function index(Request $request): JsonResponse
    {
        $range = $request->query('range');

        $reportsQuery = Report::with(['user:id,first_name,last_name', 'reportable'])
            ->where('status', 'pending')
            ->orderBy('created_at', 'desc');

        $startDate = $this->resolveStartDate($range);
        if ($startDate !== null) {
            $reportsQuery->where('created_at', '>=', $startDate);
        }

        $reports = $reportsQuery
            ->get()
            ->map(function (Report $r) {
                $reportable = $r->reportable;
                $summary = null;
                if ($reportable instanceof User) {
                    $summary = ['type' => 'user', 'id' => $reportable->id, 'name' => $reportable->name ?? '', 'email' => $reportable->email ?? ''];
                } elseif ($reportable instanceof Recipe) {
                    $summary = ['type' => 'recipe', 'id' => $reportable->id, 'title' => $reportable->title ?? ''];
                } elseif ($reportable instanceof Post) {
                    $summary = ['type' => 'post', 'id' => $reportable->id, 'content' => Str::limit($reportable->content ?? '', 50)];
                }
                return [
                    'id' => $r->id,
                    'reporter' => $r->user ? $r->user->name : null,
                    'reason' => $r->reason,
                    'details' => $r->details,
                    'status' => $r->status,
                    'created_at' => $r->created_at,
                    'reportable' => $summary,
                ];
            });

        return response()->json($reports);
    }

    public function deleteAllReports(Request $request): JsonResponse
    {
        Report::where('status', 'pending')->delete();
        ActivityLogService::log('admin_moderation', 'delete_all_reports', 'All pending reports deleted.', $request->user()->id);
        return response()->json(['message' => 'All pending reports deleted.']);
    }

    /**
     * Approve (dismiss) a report.
     */
    public function approve(Report $report, Request $request): JsonResponse
    {
        if ($report->status !== 'pending') {
            return response()->json(['message' => 'Report already processed'], 400);
        }
        $report->status = 'approved';
        $report->save();
        ActivityLogService::log('content_moderation', 'moderation_approve', 'Report approved', $request->user()->id, $report, ['ip_address' => $request->ip()]);
        return response()->json(['message' => 'Report approved (dismissed).', 'report' => $report]);
    }

    public function dismiss(Report $report, Request $request): JsonResponse
    {
        if ($report->status !== 'pending') {
            return response()->json(['message' => 'Report already processed'], 400);
        }
        $report->status = 'dismissed';
        $report->save();
        ActivityLogService::log('admin_moderation', 'dismiss', 'Report dismissed.', $request->user()->id, $report);
        return response()->json(['message' => 'Report dismissed.'], 200);
    }

    /**
     * Remove reported content (delete recipe or post).
     */
    public function removeContent(Report $report, Request $request): JsonResponse
    {
        if ($report->status !== 'pending') {
            return response()->json(['message' => 'Report already processed'], 400);
        }
        $reportable = $report->reportable;
        if ($reportable instanceof Recipe) {
            $reportable->delete();
        } elseif ($reportable instanceof Post) {
            $reportable->delete();
        } else {
            return response()->json(['message' => 'Can only remove recipes or posts'], 400);
        }
        $report->status = 'removed';
        $report->save();
        ActivityLogService::log('admin_moderation', 'remove_content', 'Content removed.', $request->user()->id, $report);
        return response()->json(['message' => 'Content removed.']);
    }

    /**
     * Suspend reported user (for reportable_type = User).
     */
    public function suspendUser(Report $report, Request $request): JsonResponse
    {
        if ($report->status !== 'pending') {
            return response()->json(['message' => 'Report already processed'], 400);
        }
        $reportable = $report->reportable;
        if (! $reportable instanceof User) {
            return response()->json(['message' => 'Report is not for a user account'], 400);
        }
        $reportable->account_status = 'suspended';
        $reportable->save();

        $reportable->tokens()->delete();

        $report->status = 'suspended';
        $report->save();
        ActivityLogService::log('admin_moderation', 'suspend_user', 'Account suspended.', $request->user()->id, $report);
        return response()->json(['message' => 'Account suspended.', 'user_id' => $reportable->id]);
    }

    public function unbanUser(Report $report, Request $request): JsonResponse
    {

        $reportable = $report->reportable;
        if (! $reportable instanceof User) {
            return response()->json(['message' => 'Report is not for a user account'], 400);
        }

        if ($reportable->account_status !== 'suspended') {
            return response()->json(['message' => 'User is not suspended'], 400);
        }

        $reportable->account_status = 'active';
        $reportable->save();

        $report->status = 'unbanned';
        $report->save();
        ActivityLogService::log('admin_moderation', 'unban_user', 'User unbanned.', $request->user()->id, $report);
        return response()->json(['message' => 'User unbanned'], 200);
    }

    private function resolveStartDate(?string $range): ?Carbon
    {
        return match ($range) {
            'weekly' => now()->subWeek(),
            'monthly' => now()->subMonth(),
            'yearly' => now()->subYear(),
            'all' => null,
            default => null,
        };
    }
}
