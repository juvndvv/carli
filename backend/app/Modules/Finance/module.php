<?php

return [
    'id' => 'finance',
    'name' => 'Finanzas',
    'icon' => 'wallet',
    'route' => '/finanzas',
    'description' => 'Cuentas, movimientos, presupuestos, suscripciones, objetivos y deudas.',
    'notifications' => [
        'budget_threshold' => [
            'label' => 'Presupuesto al 80 % / 100 %',
            'description' => 'Al guardar un movimiento que cruza el umbral de aviso o el límite.',
            'push' => true,
            'in_app' => true,
        ],
        'upcoming_charge' => [
            'label' => 'Cargo recurrente próximo',
            'description' => 'Unos días antes de cada cargo recurrente, a las 09:00.',
            'push' => true,
            'in_app' => true,
        ],
        'recurring_pending' => [
            'label' => 'Recurrente pendiente de confirmar',
            'description' => 'El día del cargo, a las 09:00.',
            'push' => true,
            'in_app' => true,
        ],
        'goal_reached' => [
            'label' => 'Objetivo alcanzado',
            'description' => 'Al llegar al 25, 50, 75 y 100 % de un objetivo de ahorro.',
            'push' => false,
            'in_app' => false,
        ],
        'debt_reminder' => [
            'label' => 'Recordatorio de deuda',
            'description' => 'En la fecha de vencimiento de una deuda o préstamo.',
            'push' => true,
            'in_app' => true,
        ],
        'payroll_overdue' => [
            'label' => 'Nómina sin registrar',
            'description' => 'Si pasa la fecha prevista de la nómina y no se ha registrado.',
            'push' => true,
            'in_app' => true,
        ],
        'weekly_summary' => [
            'label' => 'Resumen semanal',
            'description' => 'Los lunes a las 09:00.',
            'push' => false,
            'in_app' => false,
        ],
        'bank_consent_expiring' => [
            'label' => 'Conexión bancaria a punto de caducar',
            'description' => '7 días y 1 día antes de que caduque el consentimiento del banco, a las 09:00.',
            'push' => true,
            'in_app' => true,
        ],
        'bank_sync_failed' => [
            'label' => 'Error al sincronizar un banco',
            'description' => 'Cuando una sincronización bancaria falla.',
            'push' => false,
            'in_app' => true,
        ],
    ],
];
