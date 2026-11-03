<?php

namespace App\Modules\Calendar\Google;

use RuntimeException;

/** Google answered with an error that a later retry may fix (network, 5xx, rate limit). */
class GoogleException extends RuntimeException {}
