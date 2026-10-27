<?php

namespace App\Core\Push;

enum ApnsDelivery
{
    case Delivered;
    case Failed;
    case Unregistered;
}
