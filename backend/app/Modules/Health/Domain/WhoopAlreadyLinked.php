<?php

namespace App\Modules\Health\Domain;

use RuntimeException;

/** The WHOOP member is already linked to another carli user. */
final class WhoopAlreadyLinked extends RuntimeException {}
