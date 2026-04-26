<?php

namespace App\Services;

use GuzzleHttp\Client;
use Illuminate\Support\Facades\Log;

class OllamaChatService
{
    /**
     * @param  array<int, array{role: string, content: string}>  $messages  Ollama chat messages (no system in older API — we prepend as user or use system in new API; llama3 supports system in messages)
     * @param  callable(string $accumulated, string $deltaChunk): void  $onDelta
     */
    public function streamChat(array $messages, callable $onDelta): string
    {
        $url = config('assistant.ollama_url').'/api/chat';
        $model = config('assistant.ollama_model');

        $client = new Client([
            'timeout' => 120,
            'connect_timeout' => 10,
        ]);

        $options = config('assistant.ollama_options', []);
        $options = is_array($options) ? array_filter($options, static fn ($v) => $v !== null) : [];

        $body = [
            'model' => $model,
            'messages' => $messages,
            'stream' => true,
        ];

        if ($options !== []) {
            $body['options'] = $options;
        }

        $accumulated = '';

        try {
            $response = $client->post($url, [
                'json' => $body,
                'stream' => true,
                'headers' => [
                    'Accept' => 'application/json',
                ],
            ]);
        } catch (\Throwable $e) {
            Log::error('Ollama request failed', ['error' => $e->getMessage()]);
            throw $e;
        }

        $stream = $response->getBody();
        $buffer = '';

        while (! $stream->eof()) {
            $buffer .= $stream->read(8192);
            while (($pos = strpos($buffer, "\n")) !== false) {
                $line = substr($buffer, 0, $pos);
                $buffer = substr($buffer, $pos + 1);
                $line = trim($line);
                if ($line === '') {
                    continue;
                }
                $decoded = json_decode($line, true);
                if (! is_array($decoded)) {
                    continue;
                }
                $msg = $decoded['message'] ?? null;
                if (is_array($msg) && isset($msg['content'])) {
                    $piece = (string) $msg['content'];
                    if ($piece !== '') {
                        $accumulated .= $piece;
                        $onDelta($accumulated, $piece);
                    }
                }
            }
        }

        $line = trim($buffer);
        if ($line !== '') {
            $decoded = json_decode($line, true);
            if (is_array($decoded)) {
                $msg = $decoded['message'] ?? null;
                if (is_array($msg) && isset($msg['content'])) {
                    $piece = (string) $msg['content'];
                    if ($piece !== '') {
                        $accumulated .= $piece;
                        $onDelta($accumulated, $piece);
                    }
                }
            }
        }

        return $accumulated;
    }
}
