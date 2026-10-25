<?php

namespace App\Modules\Finance\BankSync\Exceptions;

use RuntimeException;

final class InvalidBankState extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('El estado de la autorización bancaria no es válido o ha caducado.');
    }
}
