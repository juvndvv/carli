import { HttpClient } from '@angular/common/http';
import {
  computed,
  EnvironmentProviders,
  inject,
  Injectable,
  InjectionToken,
  makeEnvironmentProviders,
  signal,
  Type,
} from '@angular/core';
import { CanMatchFn, Route, Routes } from '@angular/router';
import { firstValueFrom } from 'rxjs';
import { apiUrl, unwrapData } from '../http/api';
import { PendingTypeDescriptor } from '../pending/pending.models';

export type AppModuleId = 'finance' | 'tasks' | 'health' | 'habits' | 'notes';

export interface AppModuleNavItem {
  label: string;
  path: string;
  icon: string;
  exact?: boolean;
  primary?: boolean;
}

export interface AppModuleManifest {
  id: AppModuleId;
  name: string;
  icon: string;
  basePath: string;
  description?: string;
  routes: () => Promise<Routes>;
  nav: AppModuleNavItem[];
  homeWidget?: () => Promise<Type<unknown>>;
  pendingTypes?: Record<string, PendingTypeDescriptor>;
  pendingActions?: Record<string, () => Promise<Type<unknown>>>;
  settings?: () => Promise<Type<unknown>>;
}

export interface UpcomingModule {
  id: AppModuleId;
  name: string;
  icon: string;
  description: string;
}

export interface RemoteModuleState {
  id: string;
  name?: string;
  icon?: string;
  enabled: boolean;
  route?: string;
}

export const UPCOMING_MODULES: UpcomingModule[] = [
  { id: 'tasks', name: 'Tareas', icon: 'square-check', description: 'Listas, fechas y recordatorios.' },
  { id: 'health', name: 'Salud', icon: 'heart-pulse', description: 'Peso, sueño, actividad y citas médicas.' },
  { id: 'habits', name: 'Hábitos', icon: 'flame', description: 'Rachas diarias y objetivos semanales.' },
  { id: 'notes', name: 'Notas', icon: 'notebook-pen', description: 'Notas rápidas y diario personal.' },
];

export const APP_MODULES = new InjectionToken<AppModuleManifest[]>('APP_MODULES', {
  factory: () => [],
});

export function provideAppModules(manifests: AppModuleManifest[]): EnvironmentProviders {
  return makeEnvironmentProviders([{ provide: APP_MODULES, useValue: manifests }]);
}

@Injectable({ providedIn: 'root' })
export class ModuleRegistry {
  private readonly http = inject(HttpClient);
  private readonly remote = signal<RemoteModuleState[] | null>(null);

  readonly manifests = inject(APP_MODULES);
  readonly loaded = computed(() => this.remote() !== null);
  readonly enabled = computed(() => {
    const remote = this.remote();
    if (remote === null) {
      return this.manifests;
    }
    return this.manifests.filter((manifest) => remote.find((state) => state.id === manifest.id)?.enabled ?? false);
  });
  readonly upcoming = computed(() =>
    UPCOMING_MODULES.filter((module) => !this.manifests.some((manifest) => manifest.id === module.id)),
  );
  readonly primaryNav = computed(() =>
    this.enabled()
      .flatMap((manifest) => manifest.nav.filter((item) => item.primary))
      .slice(0, 3),
  );

  async load(): Promise<void> {
    try {
      const states = await firstValueFrom(
        this.http.get<RemoteModuleState[] | { data: RemoteModuleState[] }>(apiUrl('modules')).pipe(unwrapData()),
      );
      this.remote.set(states);
    } catch {
      this.remote.set(null);
    }
  }

  isEnabled(id: AppModuleId): boolean {
    return this.enabled().some((manifest) => manifest.id === id);
  }

  manifest(id: AppModuleId): AppModuleManifest | undefined {
    return this.manifests.find((manifest) => manifest.id === id);
  }

  async setEnabled(id: AppModuleId, enabled: boolean): Promise<void> {
    const previous = this.remote();
    const base = previous ?? this.manifests.map((manifest) => ({ id: manifest.id, enabled: true }));
    const exists = base.some((state) => state.id === id);
    const next = exists
      ? base.map((state) => (state.id === id ? { ...state, enabled } : state))
      : [...base, { id, enabled }];
    this.remote.set(next);
    try {
      await firstValueFrom(this.http.patch(apiUrl(`modules/${id}`), { enabled }));
    } catch (error) {
      this.remote.set(previous);
      throw error;
    }
  }
}

export const moduleEnabledGuard =
  (id: AppModuleId): CanMatchFn =>
  async () => {
    const registry = inject(ModuleRegistry);
    if (!registry.loaded()) {
      await registry.load();
    }
    return registry.isEnabled(id);
  };

export function appModuleRoutes(manifests: AppModuleManifest[]): Route[] {
  return manifests.map((manifest) => ({
    path: manifest.basePath.replace(/^\//, ''),
    canMatch: [moduleEnabledGuard(manifest.id)],
    loadChildren: manifest.routes,
  }));
}
