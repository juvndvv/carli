<?php

namespace App\Core\Push;

use App\Models\User;

interface ApnsNotification
{
    public function toApns(User $notifiable): ApnsMessage;
}
