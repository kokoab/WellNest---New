<?php

namespace App\Http\Controllers;

use App\Models\Conversation;
use App\Models\Message;
use App\Notifications\NewMessageNotification;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use App\Events\MessageDeletedEvent;
use App\Events\NewMessageEvent;

class MessageController extends Controller
{
    /** GET /api/conversations/{conversation}/messages — list messages in a conversation (paginated). */
    public function indexByConversation(Request $request, Conversation $conversation): JsonResponse
    {
        $userId = Auth::id();
        if ((int) $conversation->user1_id !== (int) $userId && (int) $conversation->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }

        $perPage = min((int) $request->get('per_page', 20), 50);

        Log::channel('messaging')->info('Fetch conversation messages', [
            'user_id' => $userId,
            'conversation_id' => $conversation->id,
            'per_page' => $perPage,
            'page' => (int) $request->get('page', 1),
        ]);

        $messages = $conversation->messages()
            ->with(['user:id,first_name,last_name', 'attachments'])
            ->orderByDesc('created_at')
            ->paginate($perPage);

        return response()->json($messages, 200);
    }

    public function index(): JsonResponse
    {
        $userId = Auth::id();

        Log::channel('messaging')->info('List user messages', [
            'user_id' => $userId,
            'page' => (int) request()->get('page', 1),
            'per_page' => (int) request()->get('per_page', 20),
        ]);

        $messages = Message::whereHas('conversation', function ($q) use ($userId) {
            $q->where('user1_id', $userId)->orWhere('user2_id', $userId);
        })->with(['conversation:id,user1_id,user2_id', 'user:id,first_name,last_name'])->latest()->paginate(20);

        return response()->json($messages, 200);
    }

    public function show(Message $message): JsonResponse
    {
        $userId = Auth::id();
        $c = $message->conversation;
        if ((int) $c->user1_id !== (int) $userId && (int) $c->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }

        Log::channel('messaging')->info('Show message', [
            'user_id' => $userId,
            'message_id' => $message->id,
            'conversation_id' => $c->id,
        ]);

        $message->load('conversation:id,user1_id,user2_id', 'user:id,first_name,last_name', 'attachments');
        return response()->json($message, 200);
    }

    /** POST /api/conversations/{conversation}/messages — send a message (or POST /api/messages with conversation_id). */
    public function store(Request $request, ?Conversation $conversation = null): JsonResponse
    {
        if ($conversation) {
            $request->merge(['conversation_id' => $conversation->id]);
        }
        $validated = $request->validate([
            'conversation_id' => 'required|exists:conversations,id',
            'content' => 'nullable|string|max:5000',
        ]);

        $userId = Auth::id();

        Log::channel('messaging')->info('Message send request', [
            'user_id' => $userId,
            'conversation_id' => $validated['conversation_id'],
            'content_length' => isset($validated['content']) ? mb_strlen((string) $validated['content']) : 0,
        ]);

        $conv = Conversation::findOrFail($validated['conversation_id']);
        if ((int) $conv->user1_id !== (int) $userId && (int) $conv->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }

        try {
            $content = isset($validated['content']) ? trim((string) $validated['content']) : '';
            $message = Message::create([
                'conversation_id' => $conv->id,
                'user_id' => $userId,
                'content' => $content,
            ]);

            $conv->update(['last_message_at' => $message->created_at]);

            $otherUser = $conv->otherUser($request->user());
            $notificationContent = $content !== '' ? $content : '[Image]';
            $otherUser->notify(new NewMessageNotification(
                $conv->id,
                $message->id,
                $request->user()->name,
                $notificationContent
            ));

            $message->load('user:id,first_name,last_name', 'attachments');
            broadcast(new NewMessageEvent($message));

            Log::channel('messaging')->info('Message sent', [
                'user_id' => $userId,
                'conversation_id' => $conv->id,
                'message_id' => $message->id,
            ]);

            return response()->json($message, 201);
        } catch (\Throwable $e) {
            Log::channel('messaging')->error('Failed to send message', [
                'user_id' => $userId,
                'conversation_id' => $validated['conversation_id'],
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    /** Legacy create: redirect to store with conversation_id from body. */
    public function create(Request $request): JsonResponse
    {
        return $this->store($request, null);
    }

    public function update(Request $request, Message $message): JsonResponse
    {
        $userId = Auth::id();
        $c = $message->conversation;
        if ((int) $c->user1_id !== (int) $userId && (int) $c->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }
        if ((int) $message->user_id !== (int) $userId) {
            abort(403, 'Can only edit your own message.');
        }
        $validated = $request->validate(['content' => 'required|string|max:5000']);
        $message->update($validated);
        $message->load('user:id,first_name,last_name', 'attachments');
        return response()->json($message, 200);
    }

    /** Unsend: only sender can delete; other user sees "{user} deleted this message". */
    public function delete(Message $message): JsonResponse
    {
        $userId = Auth::id();
        $c = $message->conversation;
        if ((int) $c->user1_id !== (int) $userId && (int) $c->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }
        if ((int) $message->user_id !== (int) $userId) {
            abort(403, 'Can only delete your own message.');
        }

        Log::channel('messaging')->info('Delete message request', [
            'user_id' => $userId,
            'message_id' => $message->id,
            'conversation_id' => $c->id,
        ]);

        if ($message->deleted_at) {
            return response()->json($message->load('user:id,first_name,last_name', 'attachments'), 200);
        }

        $message->update([
            'deleted_at' => now(),
            'content' => '',
        ]);
        $message->load('user:id,first_name,last_name', 'attachments');
        broadcast(new MessageDeletedEvent($message));

        Log::channel('messaging')->info('Message deleted', [
            'user_id' => $userId,
            'message_id' => $message->id,
            'conversation_id' => $c->id,
        ]);

        return response()->json($message, 200);
    }

    /** PATCH /api/messages/{message}/read — mark one message as read. */
    public function markAsRead(Message $message): JsonResponse
    {
        $userId = Auth::id();
        $c = $message->conversation;
        if ((int) $c->user1_id !== (int) $userId && (int) $c->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }
        if ((int) $message->user_id === (int) $userId) {
            return response()->json($message, 200); // sender doesn't need to mark own as read
        }
        $message->update(['read_at' => now()]);
        return response()->json($message, 200);
    }

    /** PATCH /api/conversations/{conversation}/messages/read — mark all messages in conversation as read. */
    public function markConversationAsRead(Conversation $conversation): JsonResponse
    {
        $userId = Auth::id();
        if ((int) $conversation->user1_id !== (int) $userId && (int) $conversation->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }
        $conversation->messages()
            ->where('user_id', '!=', $userId)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);
        return response()->json(['message' => 'Marked as read'], 200);
    }
}
