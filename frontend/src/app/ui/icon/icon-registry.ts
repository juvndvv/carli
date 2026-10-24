import {
  EnvironmentProviders,
  inject,
  Injectable,
  InjectionToken,
  makeEnvironmentProviders,
  provideEnvironmentInitializer,
  signal,
} from '@angular/core';
import { lucideLegacyIcon, type LucideIcon, type LucideIconData } from '@lucide/angular';
import type { IconNode } from 'lucide';
import { BASE_ICONS } from './icon-set';

export type IconSource = LucideIcon | LucideIconData;

export function iconsFromNodes(nodes: Record<string, IconNode>): LucideIconData[] {
  return Object.entries(nodes).map(([name, node]) => lucideLegacyIcon(name, node as LucideIconData['node']));
}

export const APP_ICONS = new InjectionToken<IconSource[]>('APP_ICONS');

const toIconData = (source: IconSource): LucideIconData =>
  typeof source === 'function' ? source.icon : source;

@Injectable({ providedIn: 'root' })
export class IconRegistry {
  private readonly icons = signal<ReadonlyMap<string, LucideIconData>>(new Map());

  constructor() {
    this.register(...BASE_ICONS);
  }

  register(...sources: IconSource[]): void {
    this.icons.update((current) => {
      const next = new Map(current);
      for (const source of sources) {
        const data = toIconData(source);
        next.set(data.name, data);
        for (const alias of data.aliases ?? []) {
          next.set(alias, data);
        }
      }
      return next;
    });
  }

  get(name: string): LucideIconData | null {
    return this.icons().get(name) ?? null;
  }

  has(name: string): boolean {
    return this.icons().has(name);
  }
}

export function provideAppIcons(...sources: IconSource[]): EnvironmentProviders {
  return makeEnvironmentProviders([
    provideEnvironmentInitializer(() => inject(IconRegistry).register(...sources)),
  ]);
}
