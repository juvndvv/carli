import {
  EnvironmentProviders,
  inject,
  Injectable,
  InjectionToken,
  makeEnvironmentProviders,
  provideEnvironmentInitializer,
  signal,
} from '@angular/core';
import { BASE_ICONS } from './icon-set';

export type IconNode = readonly (readonly [
  tag: string,
  attrs: Readonly<Record<string, string | number>>,
])[];

export interface IconData {
  name: string;
  node: IconNode;
  aliases?: string[];
}

export function iconsFromNodes(nodes: Record<string, IconNode>): IconData[] {
  return Object.entries(nodes).map(([name, node]) => ({ name, node }));
}

export const APP_ICONS = new InjectionToken<IconData[]>('APP_ICONS');

@Injectable({ providedIn: 'root' })
export class IconRegistry {
  private readonly icons = signal<ReadonlyMap<string, IconData>>(new Map());

  constructor() {
    this.register(...BASE_ICONS);
  }

  register(...icons: IconData[]): void {
    this.icons.update((current) => {
      const next = new Map(current);
      for (const icon of icons) {
        next.set(icon.name, icon);
        for (const alias of icon.aliases ?? []) {
          next.set(alias, icon);
        }
      }
      return next;
    });
  }

  get(name: string): IconData | null {
    return this.icons().get(name) ?? null;
  }

  has(name: string): boolean {
    return this.icons().has(name);
  }
}

export function provideAppIcons(...icons: IconData[]): EnvironmentProviders {
  return makeEnvironmentProviders([
    provideEnvironmentInitializer(() => inject(IconRegistry).register(...icons)),
  ]);
}
