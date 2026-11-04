<?php

return [
    'id' => 'health',
    'name' => 'Salud',
    'icon' => 'heart-pulse',
    'route' => '/salud',
    'description' => 'Peso y composición desde la báscula, medidas del cuerpo, recuperación, sueño y esfuerzo de WHOOP, y tus hábitos.',
    'notifications' => [
        'weigh_reminder' => [
            'label' => 'Recordatorio de mediciones',
            'description' => 'A la hora y los días que elijas en Ajustes de Salud, si ese día aún te falta pesarte o tomarte las medidas.',
            'push' => true,
            'in_app' => false,
        ],
        'whoop_reconnect' => [
            'label' => 'Reconectar WHOOP',
            'description' => 'Cuando WHOOP deja de dar acceso a tus datos y hay que volver a conectarlo.',
            'push' => true,
            'in_app' => true,
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
        'reminder_weight' => true,
        'reminder_body' => false,
    ],
];
