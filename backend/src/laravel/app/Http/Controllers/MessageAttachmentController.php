<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use App\Models\MessageAttachment;
use App\Models\Message;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class MessageAttachmentController extends Controller
{
    public function index(): JsonResponse
    {
        $userId = Auth::id();
        $messageAttachments = MessageAttachment::whereHas('message.conversation', function ($q) use ($userId) {
            $q->where('user1_id', $userId)->orWhere('user2_id', $userId);
        })->with('message:id,conversation_id,user_id,content')->paginate(20);
        return response()->json($messageAttachments, 200);
    }

    public function show(MessageAttachment $messageAttachment): JsonResponse
    {
        $userId = Auth::id();
        $msg = $messageAttachment->message;
        $conv = $msg->conversation;
        if ((int) $conv->user1_id !== (int) $userId && (int) $conv->user2_id !== (int) $userId) {
            abort(403, 'Not in this conversation.');
        }
        $messageAttachment->load('message:id,conversation_id,user_id,content,read_at,created_at', 'message.user:id,first_name,last_name');
        return response()->json($messageAttachment, 200);
    }

    /** POST /api/messages/{message}/attachments — upload a file (e.g. image) for this message. */
    public function upload(Request $request, Message $message): JsonResponse
    {
        if ((int) $message->user_id !== (int) Auth::id()) {
            abort(403, 'Can only add attachments to your own message.');
        }
        $request->validate([
            'file' => ['required', 'file', 'mimes:jpeg,jpg,png,gif,webp', 'max:10240'],
        ]);
        $file = $request->file('file');
        $path = $file->store('message_attachments', 'public');
        $attachment = MessageAttachment::create([
            'message_id' => $message->id,
            'file_path' => $path,
            'file_name' => $file->getClientOriginalName(),
            'file_type' => $file->getMimeType(),
            'file_size' => $file->getSize(),
        ]);
        $baseUrl = rtrim(config('app.url'), '/');
        $attachment->load('message:id,conversation_id,user_id,content,read_at,created_at', 'message.user:id,first_name,last_name');
        return response()->json([
            'id' => $attachment->id,
            'message_id' => $attachment->message_id,
            'file_path' => $path,
            'file_url' => $baseUrl . '/storage/' . $path,
            'file_name' => $attachment->file_name,
            'file_type' => $attachment->file_type,
            'file_size' => $attachment->file_size,
        ], 201);
    }

    public function create(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'message_id' => 'required|exists:messages,id',
            'file_path' => 'required|string|max:255',
            'file_name' => 'nullable|string|max:255',
            'file_type' => 'nullable|string|max:100',
            'file_size' => 'nullable|integer|min:0',
        ]);
        $message = Message::findOrFail($validated['message_id']);
        if ((int) $message->user_id !== (int) Auth::id()) {
            abort(403, 'Can only add attachments to your own message.');
        }
        $messageAttachment = MessageAttachment::create($validated);
        return response()->json($messageAttachment, 201);
    }

    public function update(Request $request, MessageAttachment $messageAttachment): JsonResponse
    {
        $message = $messageAttachment->message;
        if ((int) $message->user_id !== (int) Auth::id()) {
            abort(403, 'Can only update attachments on your own message.');
        }
        $validated = $request->validate([
            'file_path' => 'sometimes|string|max:255',
            'file_name' => 'sometimes|string|max:255',
            'file_type' => 'sometimes|string|max:100',
            'file_size' => 'sometimes|integer|min:0',
        ]);
        $messageAttachment->update($validated);
        $messageAttachment->load('message:id,conversation_id,user_id,content,read_at,created_at', 'message.user:id,first_name,last_name');
        return response()->json($messageAttachment, 200);
    }

    public function delete(MessageAttachment $messageAttachment): JsonResponse
    {
        $message = $messageAttachment->message;
        if ((int) $message->user_id !== (int) Auth::id()) {
            abort(403, 'Can only delete attachments from your own message.');
        }
        $messageAttachment->delete();
        return response()->json(null, 204);
    }
}
