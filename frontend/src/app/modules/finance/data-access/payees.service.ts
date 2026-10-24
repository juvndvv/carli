import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { financeUrl, toHttpParams } from './finance-api';
import { CategoryKind, PayeeSuggestion } from './finance.models';

@Injectable({ providedIn: 'root' })
export class PayeesService {
  private readonly http = inject(HttpClient);

  async suggest(query: string, kind: CategoryKind | null, limit = 8): Promise<PayeeSuggestion[]> {
    const body = await firstValueFrom(
      this.http.get<{ data: PayeeSuggestion[] }>(financeUrl('payees/suggest'), {
        params: toHttpParams({ q: query.trim(), kind, limit }),
      }),
    );
    return body.data;
  }
}
