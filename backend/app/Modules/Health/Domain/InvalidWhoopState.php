<?php

namespace App\Modules\Health\Domain;

use RuntimeException;

/** The OAuth state is unknown, expired or already used. */
final class InvalidWhoopState extends RuntimeException {}
