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
        if (!Schema::hasColumn('post_comments', 'image_url')) {
            Schema::table('post_comments', function (Blueprint $table) {
                $table->string('image_url')->nullable()->after('comment');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasColumn('post_comments', 'image_url')) {
            Schema::table('post_comments', function (Blueprint $table) {
                $table->dropColumn('image_url');
            });
        }
    }
};
