<?php

namespace App\Modules\Health\Whoop;

/** WHOOP refused the access token (401); a refresh may fix it. */
final class WhoopTokenRejected extends WhoopException {}
