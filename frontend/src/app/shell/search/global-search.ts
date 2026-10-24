import { DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Router } from '@angular/router';
import { ModuleRegistry } from '@core/modules/app-module';
import { SearchResult, SearchService } from '@core/search/search.service';
import { normalizeSearchText } from '@ui/combobox/combobox';
import { UiDialog } from '@ui/dialog/dialog';
import { UiIcon } from '@ui/icon/icon';
import { UiSearch } from '@ui/search/search';
import { catchError, debounceTime, distinctUntilChanged, of, Subject, switchMap, tap } from 'rxjs';

interface SearchEntry {
  title: string;
  subtitle: string | null;
  icon: string;
  url: string;
  group: string;
}

const MIN_QUERY_LENGTH = 2;

@Component({
  selector: 'app-global-search',
  imports: [UiDialog, UiSearch, UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog heading="Buscar">
      <ui-search
        placeholder="Busca movimientos, cuentas, secciones…"
        ariaLabel="Búsqueda global"
        [value]="query()"
        (valueChange)="onQuery($event)"
        (submitted)="openActive()"
        (keydown)="onKeydown($event)"
      />
      <div class="results" role="listbox" aria-label="Resultados">
        @for (entry of entries(); track entry.url + entry.title; let index = $index) {
          @if (index === 0 || entries()[index - 1].group !== entry.group) {
            <div class="group caption" role="presentation">{{ entry.group }}</div>
          }
          <button
            type="button"
            role="option"
            class="result"
            [class.active]="index === activeIndex()"
            [attr.aria-selected]="index === activeIndex()"
            (mouseenter)="activeIndex.set(index)"
            (click)="go(entry)"
          >
            <span class="ico"><ui-icon [name]="entry.icon" /></span>
            <span class="body">
              <span class="title">{{ entry.title }}</span>
              @if (entry.subtitle) {
                <span class="subtitle">{{ entry.subtitle }}</span>
              }
            </span>
            <ui-icon name="arrow-right" class="go" [size]="16" />
          </button>
        } @empty {
          <p class="empty small">
            @if (searching()) {
              Buscando…
            } @else if (query().length >= minLength) {
              Sin resultados para «{{ query() }}».
            } @else {
              Escribe al menos {{ minLength }} letras.
            }
          </p>
        }
      </div>
      <p class="hint caption d-only">↑ ↓ para moverte · Intro para abrir · Esc para cerrar</p>
    </ui-dialog>
  `,
  styles: `
    .results {
      display: flex;
      flex-direction: column;
      max-height: 50vh;
      overflow: auto;
    }
    .group {
      padding: 12px 4px 4px;
    }
    .result {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 8px;
      border: 0;
      border-radius: var(--r-md);
      background: none;
      color: var(--text);
      text-align: left;
      min-height: 52px;
    }
    .result.active {
      background: var(--surface-2);
    }
    .ico {
      width: 36px;
      height: 36px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      background: var(--surface-2);
      flex: none;
    }
    .result.active .ico {
      background: var(--bg);
    }
    .body {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
    }
    .title {
      font-weight: 500;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .subtitle {
      font-size: 13px;
      color: var(--text-3);
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .go {
      color: var(--text-3);
    }
    .empty {
      color: var(--text-3);
      padding: 16px 4px;
      text-align: center;
    }
    .hint {
      text-align: center;
    }
  `,
})
export class AppGlobalSearch {
  private readonly router = inject(Router);
  private readonly search = inject(SearchService);
  private readonly registry = inject(ModuleRegistry);
  private readonly dialogRef = inject(DialogRef, { optional: true });
  private readonly queries = new Subject<string>();

  protected readonly minLength = MIN_QUERY_LENGTH;
  protected readonly query = signal('');
  protected readonly remote = signal<SearchResult[]>([]);
  protected readonly searching = signal(false);
  protected readonly activeIndex = signal(0);

  private readonly sections = computed<SearchEntry[]>(() => [
    { title: 'Inicio', subtitle: null, icon: 'house', url: '/', group: 'Secciones' },
    ...this.registry.enabled().flatMap((module) =>
      module.nav.map((item) => ({
        title: item.label,
        subtitle: module.name,
        icon: item.icon,
        url: item.path,
        group: 'Secciones',
      })),
    ),
    { title: 'Ajustes', subtitle: 'Cuenta', icon: 'settings', url: '/ajustes', group: 'Secciones' },
    { title: 'Notificaciones', subtitle: 'Bandeja', icon: 'bell', url: '/notificaciones', group: 'Secciones' },
  ]);

  protected readonly entries = computed<SearchEntry[]>(() => {
    const term = normalizeSearchText(this.query());
    const sections = term
      ? this.sections().filter((entry) => normalizeSearchText(`${entry.title} ${entry.subtitle ?? ''}`).includes(term))
      : this.sections().slice(0, 6);
    const results = this.remote().map((result) => ({
      title: result.title,
      subtitle: result.subtitle ?? null,
      icon: result.icon ?? 'search',
      url: result.url,
      group: this.registry.manifest(result.module as never)?.name ?? 'Resultados',
    }));
    return [...results, ...sections];
  });

  constructor() {
    this.queries
      .pipe(
        debounceTime(250),
        distinctUntilChanged(),
        tap((query) => this.searching.set(query.length >= MIN_QUERY_LENGTH)),
        switchMap((query) =>
          query.length >= MIN_QUERY_LENGTH ? this.search.search(query).pipe(catchError(() => of([]))) : of([]),
        ),
        takeUntilDestroyed(inject(DestroyRef)),
      )
      .subscribe((results) => {
        this.remote.set(results);
        this.searching.set(false);
        this.activeIndex.set(0);
      });
  }

  protected onQuery(query: string): void {
    this.query.set(query);
    this.activeIndex.set(0);
    this.queries.next(query.trim());
  }

  protected onKeydown(event: KeyboardEvent): void {
    const count = this.entries().length;
    if (count === 0) {
      return;
    }
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      this.activeIndex.set((this.activeIndex() + 1) % count);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      this.activeIndex.set((this.activeIndex() - 1 + count) % count);
    }
  }

  protected openActive(): void {
    const entry = this.entries()[this.activeIndex()];
    if (entry) {
      this.go(entry);
    }
  }

  protected go(entry: SearchEntry): void {
    this.dialogRef?.close();
    void this.router.navigateByUrl(entry.url);
  }
}
