<?php

return [
    'id' => 'tasks',
    'name' => 'Tareas',
    'icon' => 'list-checks',
    'route' => '/tareas',
    'description' => 'Tareas sueltas, listas y plantillas que se repiten.',
    'notifications' => [
        'task_due' => [
            'label' => 'Aviso a la hora de la tarea',
            'description' => 'Cuando llega la hora que le has puesto a una tarea pendiente.',
            'push' => true,
            'in_app' => false,
        ],
    ],
    'settings' => [
        'default_list_id' => null,
        'default_policy' => 'replace',
        'show_done_in_today' => true,
    ],
];
