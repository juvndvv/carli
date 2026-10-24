<?php

return [
    'id' => 'journal',
    'name' => 'Diario',
    'icon' => 'book',
    'route' => '/diario',
    'settings' => ['reminder_hour' => 21],
    'notifications' => [
        'daily_reminder' => ['label' => 'Recordatorio diario', 'push' => true, 'in_app' => true],
        'weekly_digest' => ['label' => 'Resumen semanal', 'push' => false, 'in_app' => false],
    ],
];
