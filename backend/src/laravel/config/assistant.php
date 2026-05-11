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

    /*
    | Ollama generation options (passed to /api/chat). "num_predict" caps how many
    | tokens the model may emit — the main lever for short answers when the model
    | ignores "be concise" in the system prompt. Tune via .env without code changes.
    */
    'ollama_options' => [
        'num_predict' => (int) env('ASSISTANT_NUM_PREDICT', 220),
        'temperature' => (float) env('ASSISTANT_TEMPERATURE', 0.55),
    ],

    /** Max recipes injected into the assistant system prompt (DB-backed catalog). */
    'recipe_catalog_limit' => (int) env('ASSISTANT_RECIPE_CATALOG_LIMIT', 24),

    /** When keyword/search yields nothing but the message looks food-related, offer recent DB recipes. */
    'recipe_catalog_fallback_recent' => filter_var(
        env('ASSISTANT_RECIPE_CATALOG_FALLBACK', true),
        FILTER_VALIDATE_BOOL,
    ),

    'recipe_catalog_fallback_limit' => (int) env('ASSISTANT_RECIPE_CATALOG_FALLBACK_LIMIT', 15),

    /** Max recipe chips per assistant message (explicit RECIPES line + title matches). */
    'recipe_suggestion_links_max' => (int) env('ASSISTANT_RECIPE_SUGGESTION_LINKS_MAX', 5),

    /** Used with recipe search hits to detect meal/recipe intent (case-insensitive substring match). */
    'food_intent_keywords' => [
        'meal', 'meals', 'recipe', 'recipes', 'food', 'eat', 'eating', 'cook', 'cooking',
        'breakfast', 'lunch', 'dinner', 'snack', 'snacks', 'healthy eating', 'nutrition',
        'diet', 'ingredient', 'ingredients', 'dish', 'dishes', 'kitchen', 'grocery',
        'vegetarian', 'vegan', 'keto', 'protein', 'carb', 'calorie', 'smoothie', 'soup',
        'salad', 'dessert', 'idea', 'ideas', 'quick', 'light',
    ],

    'system_prompt' => <<<'PROMPT'
First: keep every reply to at most two short sentences unless the user explicitly asks for detail, steps, or a list.
You are WellNest Assistant, a supportive wellness companion for the WellNest app.
You give practical, non-judgmental suggestions about healthy eating, routines, and motivation.
You are not a doctor or therapist: do not diagnose, prescribe, or give personal medical advice.
For urgent mental health or medical crises, encourage contacting local emergency services or a qualified professional.
Keep replies concise and conversational unless the user asks for detail. Always keep your responses concise and straight to the point. Do not answer any questions or queries that  are not related to the WellNest app or the user's account.
When discussing meals or recipes, you must only reference foods and recipes that exist in WellNest (the app database); never invent dish names or external brands unless the model instructions append an explicit catalog list.
PROMPT,
];
