<?php

namespace App\Http\Controllers;

use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ConversationController extends Controller
{
    /** GET /api/conversations/assistant — get or create the WellNest Assistant thread. */
    public function assistant(Request $request): JsonResponse
    {
        $botId = \App\Support\Assistant::botUserId();
        if (! $botId) {
            return response()->json(['message' => 'Assistant is not configured. Run migrations and AssistantBotSeeder.'], 503);
        }

        $userId = Auth::id();
        $user1Id = min((int) $userId, $botId);
        $user2Id = max((int) $userId, $botId);

        $conversation = Conversation::firstOrCreate(
            ['user1_id' => $user1Id, 'user2_id' => $user2Id],
            ['last_message_at' => null]
        );

        $conversation->load('user1:id,first_name,last_name,profile_photo_url', 'user2:id,first_name,last_name,profile_photo_url');
        $other = $conversation->otherUser($request->user());

        return response()->json([
            'id' => $conversation->id,
            'is_assistant' => true,
            'other_user' => [
                'id' => $other->id,
                'name' => $other->name,
                'profile_photo_url' => $this->fixMediaUrl($other->profile_photo_url ?? ''),
            ],
        ], 200);
    }

    /** GET /api/conversations — list current user's conversations (Messenger-style). */
    public function index(Request $request): JsonResponse
    {
        $userId = Auth::id();
        $botId = \App\Support\Assistant::botUserId();

        $conversations = Conversation::where('user1_id', $userId)
            ->orWhere('user2_id', $userId)
            ->with([
                'user1:id,first_name,last_name,profile_photo_url',
                'user2:id,first_name,last_name,profile_photo_url',
                'messages' => function ($query) {
                    $query->latest()->limit(1);
                },
            ])
            ->orderByDesc('last_message_at')
            ->get();

        $list = $conversations->map(function (Conversation $c) use ($userId, $botId) {
            $other = (int) $c->user1_id === (int) $userId ? $c->user2 : $c->user1;
            $lastMessage = $c->messages->first();
            $unreadCount = $c->messages()
                ->whereNull('read_at')
                ->where('user_id', '!=', $userId)
                ->count();

            $isAssistant = $botId && (int) $other->id === (int) $botId;

            return [
                'id' => $c->id,
                'is_assistant' => $isAssistant,
                'other_user' => [
                    'id' => $other->id,
                    'name' => $other->name,
                    'profile_photo_url' => $this->fixMediaUrl($other->profile_photo_url ?? ''),
                ],
                'last_message' => $lastMessage ? [
                    'content' => strlen($lastMessage->content) > 80 ? substr($lastMessage->content, 0, 80) . '...' : $lastMessage->content,
                    'created_at' => $lastMessage->created_at->toIso8601String(),
                    'is_from_me' => (int) $lastMessage->user_id === (int) $userId,
                ] : null,
                'unread_count' => $unreadCount,
                'last_message_at' => $c->last_message_at?->toIso8601String(),
            ];
        });

        $sorted = $list->sortByDesc(function (array $row) {
            return $row['is_assistant'] ? 1 : 0;
        })->values();

        return response()->json(['data' => $sorted], 200);
    }

    /** GET /api/conversations/{conversation} — show one conversation (with paginated messages). */
    public function show(Request $request, Conversation $conversation): JsonResponse
    {
        $userId = Auth::id();
        if ((int) $conversation->user1_id !== (int) $userId && (int) $conversation->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }

        $conversation->load('user1:id,first_name,last_name,profile_photo_url', 'user2:id,first_name,last_name,profile_photo_url');
        $other = $conversation->otherUser($request->user());
        $perPage = min((int) $request->get('per_page', 20), 50);
        $messages = $conversation->messages()
            ->with(['user:id,first_name,last_name,profile_photo_url', 'attachments'])
            ->orderByDesc('created_at')
            ->paginate($perPage);

        return response()->json([
            'conversation' => [
                'id' => $conversation->id,
                'other_user' => [
                    'id' => $other->id,
                    'name' => $other->name,
                    'profile_photo_url' => $this->fixMediaUrl($other->profile_photo_url ?? ''),
                ],
            ],
            'messages' => $messages,
        ], 200);
    }

    /** POST /api/conversations — get or create a 1:1 conversation with another user. */
    public function create(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'user_id' => 'required|exists:users,id',
        ]);
        $otherId = (int) $validated['user_id'];
        $userId = Auth::id();
        if ($otherId === $userId) {
            return response()->json(['message' => 'Cannot start conversation with yourself.'], 422);
        }

        $user1Id = min($userId, $otherId);
        $user2Id = max($userId, $otherId);

        $conversation = Conversation::firstOrCreate(
            ['user1_id' => $user1Id, 'user2_id' => $user2Id],
            ['last_message_at' => null]
        );
        $conversation->load('user1:id,first_name,last_name,profile_photo_url', 'user2:id,first_name,last_name,profile_photo_url');
        $other = $conversation->otherUser($request->user());

        return response()->json([
            'id' => $conversation->id,
            'user1_id' => $conversation->user1_id,
            'user2_id' => $conversation->user2_id,
            'other_user' => [
                'id' => $other->id,
                'name' => $other->name,
                'profile_photo_url' => $this->fixMediaUrl($other->profile_photo_url ?? ''),
            ],
        ], 201);
    }

    public function update(Request $request, Conversation $conversation): JsonResponse
    {
        $userId = Auth::id();
        if ((int) $conversation->user1_id !== (int) $userId && (int) $conversation->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }
        // No meaningful update for 1:1 conversation; return as-is
        $conversation->load('user1:id,first_name,last_name', 'user2:id,first_name,last_name');
        return response()->json($conversation, 200);
    }

    public function delete(Conversation $conversation): JsonResponse
    {
        $userId = Auth::id();
        if ((int) $conversation->user1_id !== (int) $userId && (int) $conversation->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }
        $conversation->delete();
        return response()->json(null, 204);
    }

    private function fixMediaUrl(string $url): string
    {
        if ($url === '') {
            return '';
        }

        return str_replace('localhost:8000', 'localhost:8080', $url);
    }
}
