<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\Models\Vote;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\Recipe;


class DummyDataSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $targetUsers = (int) env('DUMMY_USERS_COUNT', 500);
        $targetRecords = (int) env('DUMMY_DATA_COUNT', 2000);

        if ($targetRecords <= 0) {
            return;
        }

        // Ensure there are enough regular users to make the app feel active.
        $existingRegularUsers = User::query()->where('is_admin', false)->get();
        $missingUsers = max(0, $targetUsers - $existingRegularUsers->count());
        if ($missingUsers > 0) {
            User::factory()->count($missingUsers)->create();
        }

        $users = User::query()->where('is_admin', false)->get();
        $categories = Category::query()->get();
        if ($categories->isEmpty()) {
            Category::factory()->count(10)->create();
            $categories = Category::query()->get();
        }

        $posts = Post::query()->inRandomOrder()->limit(300)->get();
        $recipes = Recipe::query()->inRandomOrder()->limit(200)->get();

        $createdPosts = 0;
        $createdMessages = 0;
        $createdComments = 0;
        $createdVotes = 0;
        $createdRecipes = 0;

        for ($i = 0; $i < $targetRecords; $i++) {
            $roll = random_int(1, 100);

            if ($roll <= 38) {
                $post = Post::factory()->create([
                    'user_id' => $users->random()->id,
                    'recipe_id' => $recipes->isNotEmpty() && random_int(1, 100) <= 35
                        ? $recipes->random()->id
                        : null,
                ]);

                $posts->push($post);
                $createdPosts++;
                continue;
            }

            if ($roll <= 66) {
                $userA = $users->random();
                $userB = $users->where('id', '!=', $userA->id)->random();
                $pair = [$userA->id, $userB->id];
                sort($pair);

                $conversation = Conversation::firstOrCreate(
                    ['user1_id' => $pair[0], 'user2_id' => $pair[1]]
                );

                $senderId = random_int(0, 1) === 0 ? $pair[0] : $pair[1];
                $createdAt = fake()->dateTimeBetween('-90 days', 'now');

                Message::create([
                    'conversation_id' => $conversation->id,
                    'user_id' => $senderId,
                    'content' => fake()->sentence(random_int(6, 20)),
                    'read_at' => random_int(1, 100) <= 70 ? fake()->dateTimeBetween($createdAt, 'now') : null,
                    'created_at' => $createdAt,
                    'updated_at' => $createdAt,
                ]);

                $conversation->update(['last_message_at' => $createdAt]);
                $createdMessages++;
                continue;
            }

            if ($roll <= 82) {
                if ($posts->isEmpty()) {
                    $posts->push(Post::factory()->create(['user_id' => $users->random()->id]));
                }

                PostComment::factory()->create([
                    'user_id' => $users->random()->id,
                    'post_id' => $posts->random()->id,
                ]);
                $createdComments++;
                continue;
            }

            if ($roll <= 92) {
                $recipe = Recipe::factory()->create([
                    'user_id' => $users->random()->id,
                    'category_id' => $categories->random()->id,
                ]);
                $recipes->push($recipe);
                $createdRecipes++;
                continue;
            }

            if ($posts->isEmpty()) {
                $posts->push(Post::factory()->create(['user_id' => $users->random()->id]));
            }

            Vote::factory()->create([
                'user_id' => $users->random()->id,
                'votable_id' => $posts->random()->id,
                'votable_type' => Post::class,
            ]);
            $createdVotes++;
        }

        if ($this->command) {
            $this->command->info("Dummy dataset created: {$targetRecords} records.");
            $this->command->info("Posts: {$createdPosts}, Messages: {$createdMessages}, Comments: {$createdComments}, Recipes: {$createdRecipes}, Votes: {$createdVotes}");
        }
    }
}
