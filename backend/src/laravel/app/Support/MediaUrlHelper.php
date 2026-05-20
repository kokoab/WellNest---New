<?php

namespace App\Support;

final class MediaUrlHelper
{
    /**
     * Normalize legacy dev URLs (port 8000) to the Docker nginx port (8080).
     */
    public static function fixLocalDevPort(string $url): string
    {
        if ($url === '') {
            return '';
        }

        return str_replace('localhost:8000', 'localhost:8080', $url);
    }
}
