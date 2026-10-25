<?php

namespace App\Modules\Finance\BankSync\Exceptions;

use Illuminate\Http\JsonResponse;
use RuntimeException;
use Throwable;

class BankProviderException extends RuntimeException
{
    public function __construct(string $message, public readonly ?int $status = null, ?Throwable $previous = null)
    {
        parent::__construct($message, $status ?? 0, $previous);
    }

    public function render(): JsonResponse
    {
        return response()->json(['message' => $this->getMessage()], $this->httpStatus());
    }

    protected function httpStatus(): int
    {
        return 502;
    }

    public function isSessionInvalid(): bool
    {
        return in_array($this->status, [401, 403, 404], true);
    }
}
