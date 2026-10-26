<?php

namespace App\Modules\Finance\BankSync\Data;

enum BankReturnTarget: string
{
    case Web = 'web';
    case App = 'app';
}
