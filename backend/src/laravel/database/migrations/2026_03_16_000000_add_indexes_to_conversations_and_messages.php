<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('conversations', function (Blueprint $table) {
            // Speed up lookups of all conversations for a user,
            // and ordering by last activity in inbox lists.
            $table->index('user1_id');
            $table->index('user2_id');
            $table->index('last_message_at');
        });

        Schema::table('messages', function (Blueprint $table) {
            // Existing index on (conversation_id, created_at) is kept.
            // Additional indexes target read/unread filters and per-user queries.
            $table->index('user_id');
            $table->index('read_at');
            $table->index(['conversation_id', 'read_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('conversations', function (Blueprint $table) {
            $table->dropIndex(['user1_id']);
            $table->dropIndex(['user2_id']);
            $table->dropIndex(['last_message_at']);
        });

        Schema::table('messages', function (Blueprint $table) {
            $table->dropIndex(['user_id']);
            $table->dropIndex(['read_at']);
            $table->dropIndex(['conversation_id', 'read_at']);
        });
    }
};

