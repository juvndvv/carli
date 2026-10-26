<?php

namespace App\Modules\Tasks\Models;

use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * @property string $id
 * @property string $template_id
 * @property CarbonImmutable $date
 * @property CarbonImmutable|null $created_at
 */
class TaskTemplateException extends Model
{
    use HasUuids;

    public const UPDATED_AT = null;

    protected $table = 'tasks.task_template_exceptions';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'date' => 'immutable_date',
            'created_at' => 'immutable_datetime',
        ];
    }
}
