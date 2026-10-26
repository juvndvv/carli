<?php

namespace App\Modules\Notes\Domain\Enums;

enum OperationStatus: string
{
    case Applied = 'applied';

    case Duplicate = 'duplicate';

    case Stale = 'stale';

    case Rejected = 'rejected';
}
