<?php

namespace App\Modules\Calendar\Domain;

use RuntimeException;

/** The consent screen came back without the Calendar permission ticked. */
final class MissingCalendarScope extends RuntimeException {}
