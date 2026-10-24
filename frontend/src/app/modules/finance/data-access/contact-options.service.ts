import { httpResource } from '@angular/common/http';
import { computed, inject, Injectable } from '@angular/core';
import { financeUrl } from './finance-api';
import { FinanceChanges } from './finance-changes';
import { ContactOption } from './finance.models';

@Injectable({ providedIn: 'root' })
export class ContactOptionsService {
  private readonly changes = inject(FinanceChanges);

  private readonly resource = httpResource<{ data: ContactOption[] }>(() => {
    this.changes.version('contacts')();
    return financeUrl('contacts');
  });

  readonly all = computed(() => (this.resource.hasValue() ? this.resource.value().data : []));
  readonly active = computed(() => this.all().filter((contact) => !contact.archived));
  readonly loaded = computed(() => this.resource.hasValue());

  find(id: string): ContactOption | undefined {
    return this.all().find((contact) => contact.id === id);
  }

  reload(): void {
    this.resource.reload();
  }
}
