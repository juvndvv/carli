import {
  computed,
  EnvironmentInjector,
  EnvironmentProviders,
  inject,
  Injectable,
  makeEnvironmentProviders,
  provideEnvironmentInitializer,
  runInInjectionContext,
  signal,
} from '@angular/core';
import { AppModuleId, ModuleRegistry } from './modules/app-module';

export interface QuickAddOpener {
  id: string;
  label: string;
  icon: string;
  module?: AppModuleId;
  order?: number;
  open: () => void | Promise<unknown>;
}

@Injectable({ providedIn: 'root' })
export class QuickAddRegistry {
  private readonly injector = inject(EnvironmentInjector);
  private readonly modules = inject(ModuleRegistry);
  private readonly registered = signal<QuickAddOpener[]>([]);

  readonly openers = computed(() => {
    const enabled = new Set(this.modules.enabled().map((manifest) => manifest.id));
    return this.registered()
      .filter((opener) => !opener.module || enabled.has(opener.module))
      .sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
  });
  readonly primary = computed(() => this.openers()[0] ?? null);

  register(opener: QuickAddOpener): () => void {
    this.registered.update((openers) => [...openers.filter((item) => item.id !== opener.id), opener]);
    return () => this.registered.update((openers) => openers.filter((item) => item !== opener));
  }

  async open(id?: string): Promise<boolean> {
    const opener = id ? this.openers().find((item) => item.id === id) : this.primary();
    if (!opener) {
      return false;
    }
    await runInInjectionContext(this.injector, () => opener.open());
    return true;
  }
}

export function provideQuickAdd(...openers: QuickAddOpener[]): EnvironmentProviders {
  return makeEnvironmentProviders([
    provideEnvironmentInitializer(() => {
      const registry = inject(QuickAddRegistry);
      openers.forEach((opener) => registry.register(opener));
    }),
  ]);
}
