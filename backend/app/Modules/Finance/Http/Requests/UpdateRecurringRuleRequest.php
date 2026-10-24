<?php

namespace App\Modules\Finance\Http\Requests;

final class UpdateRecurringRuleRequest extends StoreRecurringRuleRequest
{
    protected bool $partial = true;
}
