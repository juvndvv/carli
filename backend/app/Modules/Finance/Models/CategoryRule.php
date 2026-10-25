<?php

namespace App\Modules\Finance\Models;

use App\Modules\Finance\Domain\Enums\CategoryKind;
use App\Modules\Finance\Models\Concerns\BelongsToUser;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property string $id
 * @property string $user_id
 * @property string $pattern
 * @property CategoryKind $kind
 * @property string $category_id
 * @property CarbonImmutable|null $created_at
 * @property CarbonImmutable|null $updated_at
 * @property-read Category $category
 */
class CategoryRule extends Model
{
    use BelongsToUser, HasUuids;

    protected $table = 'finance.category_rules';

    protected $guarded = ['id', 'user_id'];

    protected function casts(): array
    {
        return [
            'kind' => CategoryKind::class,
            'created_at' => 'immutable_datetime',
            'updated_at' => 'immutable_datetime',
        ];
    }

    /**
     * @return BelongsTo<Category, $this>
     */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class)->withoutGlobalScopes();
    }
}
