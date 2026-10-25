import { inject, Injectable, Type } from '@angular/core';
import { AppModuleManifest, ModuleRegistry } from '../modules/app-module';
import { PendingItem, PendingTypeDescriptor } from './pending.models';

export interface PendingActionInputs {
  item: PendingItem;
}

const FALLBACK_ICON = 'inbox';

export function fallbackPendingDescriptor(type: string): PendingTypeDescriptor {
  const words = type.replace(/[_.-]+/g, ' ').trim();
  const label = words === '' ? 'Pendientes' : words.charAt(0).toUpperCase() + words.slice(1);
  return {
    label,
    icon: FALLBACK_ICON,
    countLabel: (count) => (count === 1 ? '1 pendiente' : `${count} pendientes`),
  };
}

@Injectable({ providedIn: 'root' })
export class PendingActions {
  private readonly registry = inject(ModuleRegistry);
  private readonly cache = new Map<string, Promise<Type<unknown> | null>>();

  manifest(module: string): AppModuleManifest | undefined {
    return this.registry.manifests.find((manifest) => manifest.id === module);
  }

  describe(module: string, type: string): PendingTypeDescriptor {
    return this.manifest(module)?.pendingTypes?.[type] ?? fallbackPendingDescriptor(type);
  }

  hasAction(module: string, type: string): boolean {
    return this.manifest(module)?.pendingActions?.[type] !== undefined;
  }

  action(module: string, type: string): Promise<Type<unknown> | null> {
    const key = `${module}:${type}`;
    let loading = this.cache.get(key);
    if (!loading) {
      const loader = this.manifest(module)?.pendingActions?.[type];
      loading = loader
        ? loader().catch(() => {
            this.cache.delete(key);
            return null;
          })
        : Promise.resolve(null);
      this.cache.set(key, loading);
    }
    return loading;
  }
}
