<?php

return [
    'id' => 'tasks',
    'name' => 'Tareas',
    'icon' => 'list-checks',
    'route' => '/tareas',
    'description' => 'Tareas sueltas, listas y plantillas que se repiten.',
    'notifications' => [],
    'settings' => [
        'default_list_id' => null,
        'default_policy' => 'replace',
        'show_done_in_today' => true,
    ],
];
