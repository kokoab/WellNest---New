<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;

class PostController extends Controller
{
    public function index()
    {
        return Post::with('user:id,first_name,last_name')
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(fn (Post $p) => [
                'id' => $p->id,
                'content' => $p->content,
                'image_url' => $p->image_url ?? '',
                'user' => ['name' => trim(($p->user->first_name ?? '') . ' ' . ($p->user->last_name ?? ''))],
            ]);
    }
}
