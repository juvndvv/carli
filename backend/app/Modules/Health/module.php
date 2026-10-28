<?php

return [
    'id' => 'health',
    'name' => 'Salud',
    'icon' => 'heart-pulse',
    'route' => '/salud',
    'description' => 'Peso y composición corporal desde la báscula, y tus hábitos.',
    'notifications' => [
        'weigh_reminder' => [
            'label' => 'Recordatorio para pesarse',
            'description' => 'A la hora y los días que elijas en Ajustes de Salud, si ese día aún no te has pesado.',
            'push' => true,
            'in_app' => false,
        ],
    ],
    'settings' => [
        'height_cm' => null,
        'birth_date' => null,
        'sex' => null,
        'goal_kg' => null,
        'reminder_enabled' => false,
        'reminder_time' => '08:00',
        'reminder_days' => [1, 2, 3, 4, 5, 6, 7],
    ],
];
