<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('recipes', function (Blueprint $table) {
            $table->string('prep_timing_mode', 20)->default('overall')->after('prep_time');
        });

        Schema::create('recipe_steps', function (Blueprint $table) {
            $table->id();
            $table->foreignId('recipe_id')->constrained()->cascadeOnDelete();
            $table->unsignedInteger('sort_order')->default(0);
            $table->string('title')->nullable();
            $table->text('instructions')->nullable();
            $table->unsignedSmallInteger('prep_time_minutes')->nullable();
            $table->timestamps();

            $table->index(['recipe_id', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('recipe_steps');

        Schema::table('recipes', function (Blueprint $table) {
            $table->dropColumn('prep_timing_mode');
        });
    }
};
