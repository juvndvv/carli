<?php

namespace App\Core\Push;

/**
 * What a push token belongs to: the app (alerts) or its widgets (silent timeline reloads).
 */
enum PushDeviceKind: string
{
    case App = 'app';
    case Widgets = 'widgets';
}
