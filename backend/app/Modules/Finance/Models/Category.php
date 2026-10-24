<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\CategoryKind;
use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * @property string $id
 * @property string $user_id
 * @property string|null $parent_id
 * @property string $name
 * @property CategoryKind $kind
 * @property string|null $icon
 * @property string|null $color
 * @property int $sort_order
 * @property bool $opens_period
 * @property CarbonImmutable|null $archived_at
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Category|null $parent
 */
class Category extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.categories';

    protected $guarded = ['id', 'user_id'];

    protected $attributes = [
        'sort_order' => 0,
        'opens_period' => false,
    ];

    protected function casts(): array
    {
        return [
            'kind' => CategoryKind::class,
            'sort_order' => 'integer',
            'opens_period' => 'boolean',
            'archived_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Category, $this>
     */
    public function parent(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'parent_id');
    }

    /**
     * @return HasMany<Category, $this>
     */
    public function children(): HasMany
    {
        return $this->hasMany(Category::class, 'parent_id')->orderBy('sort_order')->orderBy('name');
    }

    /**
     * @return list<string>
     */
    public function selfAndChildIds(): array
    {
        return array_values(array_merge(
            [$this->id],
            Category::query()->withoutGlobalScopes()->where('parent_id', $this->id)->pluck('id')->all(),
        ));
    }
}
