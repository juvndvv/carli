<?php

namespace App\Modules\Calendar\Google;

/** The refresh token no longer works (revoked, expired or password changed): the account must be connected again. */
final class GoogleAccessRevoked extends GoogleException {}
