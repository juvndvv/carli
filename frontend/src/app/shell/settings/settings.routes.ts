import { Routes } from '@angular/router';

export const settingsRoutes: Routes = [
  {
    path: '',
    loadComponent: () => import('./settings-page').then((m) => m.SettingsPage),
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'perfil' },
      { path: 'perfil', loadComponent: () => import('./profile-settings').then((m) => m.ProfileSettings) },
      { path: 'seguridad', loadComponent: () => import('./security-settings').then((m) => m.SecuritySettings) },
      { path: 'apariencia', loadComponent: () => import('./appearance-settings').then((m) => m.AppearanceSettings) },
      {
        path: 'notificaciones',
        loadComponent: () => import('./notification-settings').then((m) => m.NotificationSettings),
      },
      { path: 'modulos', loadComponent: () => import('./module-settings').then((m) => m.ModuleSettings) },
      {
        path: 'modulo/:moduleId',
        loadComponent: () => import('./module-settings-host').then((m) => m.ModuleSettingsHost),
      },
    ],
  },
];
