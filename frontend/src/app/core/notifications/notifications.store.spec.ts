import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideZonelessChangeDetection } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { NotificationsStore } from './notifications.store';

describe('NotificationsStore', () => {
  let store: NotificationsStore;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideZonelessChangeDetection(), provideHttpClient(), provideHttpClientTesting()],
    });
    store = TestBed.inject(NotificationsStore);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('maps the paginated inbox and pages through it', async () => {
    const refresh = store.refresh();
    http.expectOne('/api/v1/notifications?page=1').flush({
      data: [
        {
          id: 'n1',
          module: 'finance',
          type: 'upcoming_charge',
          title: 'Netflix 13,99 € pasado mañana',
          body: 'Cargo recurrente previsto.',
          url: '/finanzas/recurrentes',
          read_at: null,
          created_at: '2026-10-24T09:00:00+02:00',
        },
      ],
      meta: { current_page: 1, last_page: 2, unread_count: 7 },
    });
    await refresh;

    expect(store.items()[0].data).toEqual({
      title: 'Netflix 13,99 € pasado mañana',
      body: 'Cargo recurrente previsto.',
      url: '/finanzas/recurrentes',
      module: 'finance',
    });
    expect(store.unreadCount()).toBe(7);
    expect(store.hasMore()).toBe(true);

    const more = store.loadMore();
    http.expectOne('/api/v1/notifications?page=2').flush({
      data: [],
      meta: { current_page: 2, last_page: 2, unread_count: 7 },
    });
    await more;
    expect(store.hasMore()).toBe(false);
  });

  it('marks notifications read and adopts the server unread count', async () => {
    const mark = store.markRead(['n1']);
    const request = http.expectOne('/api/v1/notifications/read');
    expect(request.request.body).toEqual({ ids: ['n1'] });
    request.flush({ marked: 1, unread_count: 3 });
    await mark;
    expect(store.unreadCount()).toBe(3);
  });

  it('flattens grouped preferences and saves them in the backend shape', async () => {
    const load = store.preferences();
    http.expectOne('/api/v1/notification-preferences').flush({
      push_configured: true,
      data: [
        {
          module: 'finance',
          name: 'Finanzas',
          icon: 'wallet',
          enabled: true,
          types: [{ type: 'budget_threshold', label: 'Presupuesto al 80 % / 100 %', description: null, push: true, in_app: true }],
        },
      ],
    });
    const preferences = await load;
    expect(preferences).toEqual([
      {
        module_id: 'finance',
        module_name: 'Finanzas',
        type: 'budget_threshold',
        label: 'Presupuesto al 80 % / 100 %',
        description: null,
        push: true,
        in_app: true,
      },
    ]);

    const save = store.savePreferences([{ ...preferences[0], push: false }]);
    const request = http.expectOne('/api/v1/notification-preferences');
    expect(request.request.body).toEqual({
      preferences: [{ module: 'finance', type: 'budget_threshold', push: false, in_app: true }],
    });
    request.flush({});
    await save;
  });
});
