<?php

use Illuminate\Support\Facades\DB;
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
        Schema::table('users', function (Blueprint $table) {
            $table->string('account_status')->default('active')->after('status');
        });

        DB::table('users')->select('id', 'status')->orderBy('id')->chunkById(200, function ($users) {
            foreach ($users as $user) {
                $mapped = match ($user->status) {
                    'suspended' => 'suspended',
                    'inactive' => 'deactivated',
                    default => 'active',
                };
                DB::table('users')->where('id', $user->id)->update(['account_status' => $mapped]);
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('account_status');
        });
    }
};
