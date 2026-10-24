import { HttpClient } from '@angular/common/http';
import { computed, inject, Injectable, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { apiUrl } from '../http/api';

export interface AppNotificationData {
  title: string;
  body?: string | null;
  url?: string | null;
  icon?: string | null;
  module?: string | null;
  action?: { label: string; url: string } | null;
}

export interface AppNotification {
  id: string;
  type: string;
  data: AppNotificationData;
  read_at: string | null;
  created_at: string;
}

export interface NotificationPreference {
  module_id: string;
  module_name: string;
  type: string;
  label: string | null;
  description: string | null;
  push: boolean;
  in_app: boolean;
}

interface ApiNotification {
  id: string;
  module: string | null;
  type: string | null;
  title: string | null;
  body: string | null;
  url: string | null;
  read_at: string | null;
  created_at: string;
}

interface ApiNotificationPage {
  data: ApiNotification[];
  meta: { current_page: number; last_page: number; unread_count: number };
}

interface ApiPreferenceGroup {
  module: string;
  name: string;
  types: { type: string; label: string | null; description: string | null; push: boolean; in_app: boolean }[];
}

function toAppNotification(item: ApiNotification): AppNotification {
  return {
    id: item.id,
    type: item.type ?? '',
    data: { title: item.title ?? '', body: item.body, url: item.url, module: item.module },
    read_at: item.read_at,
    created_at: item.created_at,
  };
}

@Injectable({ providedIn: 'root' })
export class NotificationsStore {
  private readonly http = inject(HttpClient);
  private readonly list = signal<AppNotification[]>([]);
  private readonly nextPage = signal<number | null>(null);
  private readonly unread = signal(0);
  private readonly loadingState = signal(false);
  private readonly loadedState = signal(false);

  readonly items = this.list.asReadonly();
  readonly loading = this.loadingState.asReadonly();
  readonly loaded = this.loadedState.asReadonly();
  readonly hasMore = computed(() => this.nextPage() !== null);
  readonly unreadCount = this.unread.asReadonly();
  readonly recent = computed(() => this.list().slice(0, 3));

  async refresh(): Promise<void> {
    this.loadingState.set(true);
    try {
      const page = await this.fetchPage(1);
      this.list.set(page.data.map(toAppNotification));
      this.applyMeta(page);
      this.loadedState.set(true);
    } catch {
      this.loadedState.set(true);
    } finally {
      this.loadingState.set(false);
    }
  }

  async loadMore(): Promise<void> {
    const pageNumber = this.nextPage();
    if (!pageNumber || this.loadingState()) {
      return;
    }
    this.loadingState.set(true);
    try {
      const page = await this.fetchPage(pageNumber);
      const known = new Set(this.list().map((item) => item.id));
      this.list.update((items) => [...items, ...page.data.filter((item) => !known.has(item.id)).map(toAppNotification)]);
      this.applyMeta(page);
    } finally {
      this.loadingState.set(false);
    }
  }

  async markRead(ids?: string[]): Promise<void> {
    const now = new Date().toISOString();
    const targets = ids ? new Set(ids) : null;
    const affected = this.list().filter((item) => item.read_at === null && (!targets || targets.has(item.id))).length;
    this.list.update((items) =>
      items.map((item) => (item.read_at === null && (!targets || targets.has(item.id)) ? { ...item, read_at: now } : item)),
    );
    this.unread.update((count) => (targets ? Math.max(0, count - affected) : 0));
    try {
      const result = await firstValueFrom(
        this.http.post<{ unread_count: number }>(apiUrl('notifications/read'), ids ? { ids } : { all: true }),
      );
      this.unread.set(result.unread_count);
    } catch {
      return;
    }
  }

  async preferences(): Promise<NotificationPreference[]> {
    const response = await firstValueFrom(
      this.http.get<{ data: ApiPreferenceGroup[] }>(apiUrl('notification-preferences')),
    );
    return response.data.flatMap((group) =>
      group.types.map((type) => ({
        module_id: group.module,
        module_name: group.name,
        type: type.type,
        label: type.label,
        description: type.description,
        push: type.push,
        in_app: type.in_app,
      })),
    );
  }

  async savePreferences(preferences: NotificationPreference[]): Promise<void> {
    await firstValueFrom(
      this.http.put(apiUrl('notification-preferences'), {
        preferences: preferences.map(({ module_id, type, push, in_app }) => ({ module: module_id, type, push, in_app })),
      }),
    );
  }

  private fetchPage(page: number): Promise<ApiNotificationPage> {
    return firstValueFrom(this.http.get<ApiNotificationPage>(apiUrl('notifications'), { params: { page } }));
  }

  private applyMeta(page: ApiNotificationPage): void {
    this.unread.set(page.meta.unread_count);
    this.nextPage.set(page.meta.current_page < page.meta.last_page ? page.meta.current_page + 1 : null);
  }
}
