<?php

return [
    /*
    |--------------------------------------------------------------------------
    | WellNest Assistant (Ollama)
    |--------------------------------------------------------------------------
    |
    | The assistant is a real User row (see AssistantBotSeeder). Laravel calls
    | Ollama on your machine; the Flutter app never talks to Ollama directly.
    |
    */

    'bot_email' => env('ASSISTANT_BOT_EMAIL', 'assistant@wellnest.local'),

    /** Optional: set after seeding to skip a DB lookup */
    'bot_user_id' => env('ASSISTANT_BOT_USER_ID'),

    'ollama_url' => rtrim(env('OLLAMA_URL', 'http://127.0.0.1:11434'), '/'),

    'ollama_model' => env('OLLAMA_MODEL', 'llama3.1'),

    'history_days' => (int) env('ASSISTANT_HISTORY_DAYS', 7),

    'system_prompt' => <<<'PROMPT'
You are WellNest Assistant, a supportive wellness companion for the WellNest app.
You give practical, non-judgmental suggestions about healthy eating, routines, and motivation.
You are not a doctor or therapist: do not diagnose, prescribe, or give personal medical advice.
For urgent mental health or medical crises, encourage contacting local emergency services or a qualified professional.
Keep replies concise and conversational unless the user asks for detail.
PROMPT,
];
