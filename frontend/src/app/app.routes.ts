import { Routes } from '@angular/router';
import { authGuard, guestGuard } from '@core/auth/auth.guards';
import { appModuleRoutes } from '@core/modules/app-module';
import { APP_MODULE_MANIFESTS } from './app-modules';

export const routes: Routes = [
  {
    path: 'login',
    canMatch: [guestGuard],
    title: 'Entrar · Personal App',
    loadComponent: () => import('./shell/login/login-page').then((m) => m.LoginPage),
  },
  {
    path: 'dev/ui',
    title: 'Design system · Personal App',
    loadComponent: () => import('./dev/ui-catalog-page').then((m) => m.UiCatalogPage),
  },
  {
    path: '',
    canMatch: [authGuard],
    loadComponent: () => import('./shell/layout/app-layout').then((m) => m.AppLayout),
    children: [
      {
        path: '',
        pathMatch: 'full',
        loadComponent: () => import('./shell/home/home-page').then((m) => m.HomePage),
      },
      {
        path: 'ajustes',
        loadChildren: () => import('./shell/settings/settings.routes').then((m) => m.settingsRoutes),
      },
      {
        path: 'notificaciones',
        loadComponent: () => import('./shell/notifications/notifications-page').then((m) => m.NotificationsPage),
      },
      {
        path: 'mas',
        loadComponent: () => import('./shell/more/more-page').then((m) => m.MorePage),
      },
      ...appModuleRoutes(APP_MODULE_MANIFESTS),
    ],
  },
  { path: '**', redirectTo: '' },
];
