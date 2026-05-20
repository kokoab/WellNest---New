<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use App\Models\Report;
use App\Models\SavedRecipe;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\MessageAttachment;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use App\Models\Post;
use App\Models\PostComment;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'first_name',
        'last_name',
        'email',
        'password',
        'role',
        'profile_photo_url',
        'account_status',
        'is_admin',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Legacy `status` column remains in DB (mapped to account_status in migration);
     * use `account_status` for all new code. Admin: `role === 'admin'` or `is_admin`.
     */

    /**
     * @var list<string>
     */
    protected $appends = [
        'name',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_admin' => 'boolean',
        ];
    }

    /**
     * Virtual attribute for display name (first_name + last_name).
     */
    public function isActiveAccount(): bool
    {
        return ($this->account_status ?? 'active') === 'active';
    }

    public function isDeactivatedAccount(): bool
    {
        return $this->account_status === 'deactivated';
    }

    public function isSuspendedAccount(): bool
    {
        return $this->account_status === 'suspended';
    }

    public function getNameAttribute(): string
    {
        return trim(($this->first_name ?? '') . ' ' . ($this->last_name ?? ''));
    }

    public function votes()
    {
        return $this->hasMany(Vote::class);
    }
    public function posts()
    {
        return $this->hasMany(Post::class);
    }
    public function recipes()
    {
        return $this->hasMany(Recipe::class);
    }
    public function comments()
    {
        return $this->hasMany(PostComment::class);
    }
    public function reports()
    {
        return $this->morphMany(Report::class, 'reportable');
    }
    public function savedRecipes()
    {
        return $this->belongsToMany(Recipe::class, 'saved_recipes')
            ->withTimestamps();
    }
    public function mealPlans(): HasMany
    {
        return $this->hasMany(MealPlan::class);
    }
    /**
     * Query conversations where this user is a participant (not a single HasMany FK).
     */
    public function conversationsQuery(): \Illuminate\Database\Eloquent\Builder
    {
        return Conversation::query()
            ->where(function ($q) {
                $q->where('user1_id', $this->id)
                    ->orWhere('user2_id', $this->id);
            })
            ->orderByDesc('last_message_at');
    }

    public function followers(): BelongsToMany
    {
        return $this->belongsToMany(
            User::class,
            'user_follows',
            'following_id',
            'follower_id'
        )->withTimestamps();
    }

    public function following(): BelongsToMany
    {
        return $this->belongsToMany(
            User::class,
            'user_follows',
            'follower_id',
            'following_id'
        )->withTimestamps();
    }
}
