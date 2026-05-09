<?php

use App\Models\Image;
use App\Models\Post;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('images', function (Blueprint $table) {
            $table->unsignedInteger('sort_order')->default(0)->after('path');
        });

        // Deterministic order within each imageable: preserve insertion order by id.
        $groups = DB::table('images')
            ->select('imageable_type', 'imageable_id')
            ->groupBy('imageable_type', 'imageable_id')
            ->get();

        foreach ($groups as $g) {
            $rows = DB::table('images')
                ->where('imageable_type', $g->imageable_type)
                ->where('imageable_id', $g->imageable_id)
                ->orderBy('id')
                ->pluck('id');
            foreach ($rows as $i => $id) {
                DB::table('images')->where('id', $id)->update(['sort_order' => $i]);
            }
        }

        // Copy legacy post.image_url into polymorphic images (one row per post).
        Post::query()
            ->whereNotNull('image_url')
            ->where('image_url', '!=', '')
            ->chunkById(100, function ($posts) {
                foreach ($posts as $post) {
                    $path = $this->storagePathFromPublicUrl($post->image_url);
                    if ($path === null || $path === '') {
                        continue;
                    }
                    $exists = Image::query()
                        ->where('imageable_type', Post::class)
                        ->where('imageable_id', $post->id)
                        ->exists();
                    if ($exists) {
                        continue;
                    }
                    Image::create([
                        'path' => $path,
                        'imageable_id' => $post->id,
                        'imageable_type' => Post::class,
                        'sort_order' => 0,
                    ]);
                }
            });
    }

    public function down(): void
    {
        Schema::table('images', function (Blueprint $table) {
            $table->dropColumn('sort_order');
        });
    }

    private function storagePathFromPublicUrl(?string $url): ?string
    {
        if ($url === null || $url === '') {
            return null;
        }
        $path = parse_url($url, PHP_URL_PATH);
        if (! is_string($path) || $path === '') {
            return null;
        }
        $prefix = '/storage/';
        if (! str_starts_with($path, $prefix)) {
            return null;
        }

        return substr($path, strlen($prefix));
    }
};
