<?php

namespace App\Modules\Health\Whoop;

/** The refresh token no longer works: the member revoked access or it was rotated elsewhere. */
final class WhoopAccessRevoked extends WhoopException {}
