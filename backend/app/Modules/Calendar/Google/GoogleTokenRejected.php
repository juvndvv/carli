<?php

namespace App\Modules\Calendar\Google;

/** The Calendar API answered 401: the access token expired early and must be refreshed. */
final class GoogleTokenRejected extends GoogleException {}
