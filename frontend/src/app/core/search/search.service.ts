import { HttpClient } from '@angular/common/http';
import { inject, Injectable, signal } from '@angular/core';
import { map, Observable } from 'rxjs';
import { apiUrl } from '../http/api';

export interface SearchResult {
  module: string;
  type: string;
  id?: string;
  title: string;
  subtitle?: string | null;
  url: string;
  icon?: string | null;
}

@Injectable({ providedIn: 'root' })
export class SearchService {
  private readonly http = inject(HttpClient);
  private readonly openState = signal(false);

  readonly isOpen = this.openState.asReadonly();

  open(): void {
    this.openState.set(true);
  }

  close(): void {
    this.openState.set(false);
  }

  search(query: string): Observable<SearchResult[]> {
    return this.http.get<unknown>(apiUrl('search'), { params: { q: query } }).pipe(
      map((response) => {
        if (Array.isArray(response)) {
          return response as SearchResult[];
        }
        const body = (response ?? {}) as { data?: SearchResult[]; results?: SearchResult[] };
        return body.results ?? body.data ?? [];
      }),
    );
  }
}
