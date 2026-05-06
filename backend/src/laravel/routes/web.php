<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/reset-password/{token?}', function (Request $request, ?string $token = null) {
    $email = $request->query('email', '');

    return response()->make(
        '<!doctype html><html><head><meta charset="utf-8"><title>Reset Password</title></head><body style="font-family: sans-serif; padding: 24px;"><h1>Reset Password</h1><p>This app resets passwords inside the Flutter app.</p><p><strong>Email:</strong> ' . e($email) . '</p><p><strong>Token:</strong> ' . e($token ?? '') . '</p><p>Open the Flutter app and use the Reset Password screen with this token.</p></body></html>',
        200,
        ['Content-Type' => 'text/html; charset=UTF-8']
    );
})->name('password.reset');
