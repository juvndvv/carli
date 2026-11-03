<?php

return [
    'id' => 'calendar',
    'name' => 'Calendario',
    'icon' => 'calendar',
    'route' => '/calendario',
    'description' => 'Tus calendarios de Google junto a tareas, cargos previstos, hábitos y recordatorios.',
    'notifications' => [
        'google_reconnect' => [
            'label' => 'Reconectar Google',
            'description' => 'Cuando Google deja de dar acceso a una cuenta y hay que volver a conectarla.',
            'push' => true,
            'in_app' => true,
        ],
    ],
    'settings' => [],
];
