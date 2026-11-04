<?php

namespace App\Modules\Health\Whoop;

use RuntimeException;

/** WHOOP answered with an error that a later retry may fix (network, 5xx, rate limit). */
class WhoopException extends RuntimeException {}
