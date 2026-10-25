import { DOCUMENT } from '@angular/common';
import { HttpClient, httpResource } from '@angular/common/http';
import { computed, inject, Injectable } from '@angular/core';
import { firstValueFrom, map } from 'rxjs';
import { financeUrl } from './finance-api';
import { FinanceChanges } from './finance-changes';
import { Aspsp, BankAccountCandidate, BankAccountLinkInput, BankConnection } from './bank.models';

export const HOME_COUNTRY = 'ES';

export const EXTRA_ASPSPS: readonly { country: string; pattern: RegExp }[] = [{ country: 'LT', pattern: /revolut/i }];

export function mergeAspsps(home: Aspsp[], extra: Aspsp[]): Aspsp[] {
  const seen = new Set(home.map((aspsp) => `${aspsp.country}:${aspsp.name}`));
  return [...home, ...extra.filter((aspsp) => !seen.has(`${aspsp.country}:${aspsp.name}`))].sort((left, right) =>
    left.name.localeCompare(right.name, 'es', { sensitivity: 'base' }),
  );
}

@Injectable({ providedIn: 'root' })
export class BankRedirect {
  private readonly document = inject(DOCUMENT);

  go(url: string): void {
    this.document.location.assign(url);
  }
}

@Injectable({ providedIn: 'root' })
export class BankService {
  private readonly http = inject(HttpClient);
  private readonly changes = inject(FinanceChanges);

  private readonly resource = httpResource<{ data: BankConnection[] }>(() => {
    this.changes.version('bank')();
    return financeUrl('bank/connections');
  });

  readonly connections = computed(() => (this.resource.hasValue() ? this.resource.value().data : []));
  readonly loaded = computed(() => this.resource.hasValue());
  readonly loading = this.resource.isLoading;
  readonly error = this.resource.error;

  reload(): void {
    this.resource.reload();
  }

  async aspsps(): Promise<Aspsp[]> {
    const [home, ...extras] = await Promise.all([
      this.fetchAspsps(HOME_COUNTRY),
      ...EXTRA_ASPSPS.map(({ country, pattern }) =>
        this.fetchAspsps(country)
          .then((list) => list.filter((aspsp) => pattern.test(aspsp.name)))
          .catch(() => [] as Aspsp[]),
      ),
    ]);
    return mergeAspsps(home, extras.flat());
  }

  get(id: string): Promise<BankConnection> {
    return firstValueFrom(
      this.http.get<{ data: BankConnection }>(financeUrl(`bank/connections/${id}`)).pipe(map((body) => body.data)),
    );
  }

  async connect(aspsp: Pick<Aspsp, 'name' | 'country'>): Promise<string> {
    const body = await firstValueFrom(
      this.http.post<{ data: { auth_url: string } }>(financeUrl('bank/connections'), {
        aspsp_name: aspsp.name,
        aspsp_country: aspsp.country,
      }),
    );
    return body.data.auth_url;
  }

  bankAccounts(id: string): Promise<BankAccountCandidate[]> {
    return firstValueFrom(
      this.http
        .get<{ data: BankAccountCandidate[] }>(financeUrl(`bank/connections/${id}/accounts`))
        .pipe(map((body) => body.data)),
    );
  }

  async link(id: string, accounts: BankAccountLinkInput[]): Promise<BankConnection> {
    const body = await firstValueFrom(
      this.http.post<{ data: BankConnection }>(financeUrl(`bank/connections/${id}/accounts`), { accounts }),
    );
    this.changes.notify('bank', 'accounts');
    return body.data;
  }

  async sync(id: string): Promise<void> {
    await firstValueFrom(this.http.post(financeUrl(`bank/connections/${id}/sync`), {}));
  }

  async renew(id: string): Promise<string> {
    const body = await firstValueFrom(
      this.http.post<{ data: { auth_url: string } }>(financeUrl(`bank/connections/${id}/renew`), {}),
    );
    return body.data.auth_url;
  }

  async disconnect(id: string): Promise<void> {
    await firstValueFrom(this.http.delete(financeUrl(`bank/connections/${id}`)));
    this.changes.notify('bank', 'accounts', 'transactions');
  }

  synced(): void {
    this.changes.notify('bank');
    this.changes.notifyTransactions();
  }

  private fetchAspsps(country: string): Promise<Aspsp[]> {
    return firstValueFrom(
      this.http
        .get<{ data: Aspsp[] }>(financeUrl('bank/aspsps'), { params: { country } })
        .pipe(map((body) => body.data)),
    );
  }
}
