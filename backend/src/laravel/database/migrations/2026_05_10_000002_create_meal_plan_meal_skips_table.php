<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('meal_plan_meal_skips', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('skipped_date');
            $table->string('meal_slot', 20);
            $table->timestamps();

            $table->unique(['user_id', 'skipped_date', 'meal_slot']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('meal_plan_meal_skips');
    }
};
