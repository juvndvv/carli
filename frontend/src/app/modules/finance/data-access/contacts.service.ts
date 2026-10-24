import { HttpClient } from '@angular/common/http';
import { computed, inject, Injectable, signal } from '@angular/core';
import { firstValidationMessage } from '@core/http/api';
import { firstValueFrom, map } from 'rxjs';
import {
  ContactPayload,
  ContactsMeta,
  FinanceContact,
  FinanceContactDetail,
  SettleContactPayload,
  SettleContactResult,
} from './contacts.models';
import { FinanceAccountLookup } from './recurring.models';
import { fetchAccountLookups, financeApiUrl } from './recurring.service';

@Injectable({ providedIn: 'root' })
export class ContactsService {
  private readonly http = inject(HttpClient);

  readonly contacts = signal<FinanceContact[]>([]);
  readonly meta = signal<ContactsMeta>({ owed_to_me_cents: 0, i_owe_cents: 0 });
  readonly loading = signal(false);
  readonly loaded = signal(false);
  readonly error = signal<string | null>(null);

  readonly owingMe = computed(() => this.contacts().filter((contact) => contact.balance_cents > 0));
  readonly owedByMe = computed(() => this.contacts().filter((contact) => contact.balance_cents < 0));

  async load(): Promise<void> {
    this.loading.set(true);
    this.error.set(null);
    try {
      const response = await firstValueFrom(
        this.http.get<{ data: FinanceContact[]; meta: ContactsMeta }>(financeApiUrl('contacts')),
      );
      this.contacts.set(response.data);
      this.meta.set(response.meta);
      this.loaded.set(true);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se han podido cargar los contactos.'));
    } finally {
      this.loading.set(false);
    }
  }

  get(id: string): Promise<FinanceContactDetail> {
    return firstValueFrom(
      this.http
        .get<{ data: FinanceContactDetail }>(financeApiUrl(`contacts/${id}`))
        .pipe(map((response) => response.data)),
    );
  }

  async create(payload: ContactPayload): Promise<FinanceContactDetail> {
    const response = await firstValueFrom(
      this.http.post<{ data: FinanceContactDetail }>(financeApiUrl('contacts'), payload),
    );
    this.contacts.update((contacts) =>
      [...contacts, response.data].sort((a, b) => a.name.localeCompare(b.name, 'es')),
    );
    return response.data;
  }

  async update(id: string, patch: Partial<ContactPayload> & { archived?: boolean }): Promise<FinanceContactDetail> {
    const response = await firstValueFrom(
      this.http.patch<{ data: FinanceContactDetail }>(financeApiUrl(`contacts/${id}`), patch),
    );
    void this.load();
    return response.data;
  }

  async remove(id: string): Promise<void> {
    await firstValueFrom(this.http.delete<void>(financeApiUrl(`contacts/${id}`)));
    this.contacts.update((contacts) => contacts.filter((contact) => contact.id !== id));
    void this.load();
  }

  async settle(id: string, payload: SettleContactPayload): Promise<SettleContactResult> {
    const response = await firstValueFrom(
      this.http.post<{ data: SettleContactResult }>(financeApiUrl(`contacts/${id}/settle`), payload),
    );
    void this.load();
    return response.data;
  }

  async undoSettlement(transactionId: string): Promise<void> {
    await firstValueFrom(this.http.delete<unknown>(financeApiUrl(`transactions/${transactionId}`)));
    void this.load();
  }

  accounts(): Promise<FinanceAccountLookup[]> {
    return fetchAccountLookups(this.http);
  }
}
