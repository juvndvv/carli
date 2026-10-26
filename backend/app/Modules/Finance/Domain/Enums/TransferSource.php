<?php

namespace App\Modules\Finance\Domain\Enums;

enum TransferSource: string
{
    case Auto = 'auto';

    case Confirmed = 'confirmed';

    case Linked = 'linked';
}
