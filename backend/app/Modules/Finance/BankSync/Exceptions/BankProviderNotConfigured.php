<?php

namespace App\Modules\Finance\BankSync\Exceptions;

final class BankProviderNotConfigured extends BankProviderException
{
    public function __construct(string $message = 'La conexión bancaria no está configurada.')
    {
        parent::__construct($message);
    }

    protected function httpStatus(): int
    {
        return 503;
    }
}
