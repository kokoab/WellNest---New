<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class CorsForApi
{
    /**
     * Add permissive CORS headers for API requests.
     * This prevents Flutter web from failing "Failed to fetch" on multipart POSTs
     * (browser preflight OPTIONS).
     */
    public function handle(Request $request, Closure $next)
    {
        if (!$request->is('api/*')) {
            return $next($request);
        }

        $origin = $request->headers->get('Origin');
        $allowOrigin = $origin ?: '*';

        $allowHeaders = $request->headers->get('Access-Control-Request-Headers');
        if (!$allowHeaders) {
            $allowHeaders = 'Origin, Content-Type, Accept, Authorization';
        }

        $headers = [
            'Access-Control-Allow-Origin' => $allowOrigin,
            'Access-Control-Allow-Methods' => 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
            'Access-Control-Allow-Headers' => $allowHeaders,
            'Access-Control-Max-Age' => '86400',
            'Access-Control-Allow-Credentials' => $origin ? 'true' : 'false',
            'Vary' => 'Origin',
        ];

        if ($request->getMethod() === 'OPTIONS') {
            return response()->noContent(204)->withHeaders($headers);
        }

        $response = $next($request);
        foreach ($headers as $key => $value) {
            $response->headers->set($key, $value);
        }

        return $response;
    }
}

