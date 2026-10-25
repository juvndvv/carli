import { DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, OnInit, signal } from '@angular/core';
import { firstValidationMessage } from '@core/http/api';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiListItem } from '@ui/list-item/list-item';
import { UiSearch } from '@ui/search/search';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { Aspsp } from '../../data-access/bank.models';
import { BankRedirect, BankService, HOME_COUNTRY } from '../../data-access/bank.service';

export function aspspSubtitle(aspsp: Aspsp): string {
  const consent = `Permiso de ${aspsp.consent_days} días`;
  return aspsp.country === HOME_COUNTRY ? consent : `${aspsp.country} · ${consent}`;
}

export function matchesAspsp(aspsp: Aspsp, query: string): boolean {
  const normalize = (text: string) =>
    text
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase();
  return normalize(aspsp.name).includes(normalize(query.trim()));
}

@Component({
  selector: 'fin-connect-bank-dialog',
  imports: [UiDialog, UiButton, UiListItem, UiSearch, UiSkeleton],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog heading="Conectar banco" subtitle="Solo lectura: la app nunca puede mover tu dinero.">
      <div class="stack">
        <p class="small muted">
          Te llevaremos a la web de tu banco para que autorices el acceso. Al volver, eliges a qué cuenta va cada una y desde qué fecha
          importar movimientos.
        </p>
        <ui-search placeholder="Buscar banco" ariaLabel="Buscar banco" [value]="query()" (valueChange)="query.set($event)" />
        @if (error(); as message) {
          <p class="field-error" role="alert">{{ message }}</p>
        }
        @if (loading()) {
          <ui-skeleton height="44px" />
          <ui-skeleton height="44px" />
          <ui-skeleton height="44px" />
        } @else {
          <div class="ui-list banks" [class.busy]="connecting() !== null">
            @for (aspsp of visible(); track aspsp.country + aspsp.name) {
              <button
                type="button"
                ui-list-item
                icon="landmark"
                [heading]="aspsp.name"
                [subtitle]="connecting() === aspsp.name ? 'Abriendo tu banco…' : subtitle(aspsp)"
                (click)="connect(aspsp)"
              ></button>
            } @empty {
              <p class="small faint">No hay bancos que coincidan con «{{ query() }}».</p>
            }
          </div>
        }
        <div class="row end">
          <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        </div>
      </div>
    </ui-dialog>
  `,
  styles: `
    .banks {
      max-height: 360px;
      overflow-y: auto;
    }
    .banks.busy {
      opacity: 0.6;
      pointer-events: none;
    }
    .end {
      justify-content: flex-end;
    }
  `,
})
export class ConnectBankDialog implements OnInit {
  protected readonly ref = inject(DialogRef);
  private readonly bank = inject(BankService);
  private readonly redirect = inject(BankRedirect);

  protected readonly aspsps = signal<Aspsp[]>([]);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);
  protected readonly query = signal('');
  protected readonly connecting = signal<string | null>(null);
  protected readonly visible = computed(() => this.aspsps().filter((aspsp) => matchesAspsp(aspsp, this.query())));

  async ngOnInit(): Promise<void> {
    try {
      this.aspsps.set(await this.bank.aspsps());
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido cargar la lista de bancos.'));
    } finally {
      this.loading.set(false);
    }
  }

  protected subtitle(aspsp: Aspsp): string {
    return aspspSubtitle(aspsp);
  }

  protected async connect(aspsp: Aspsp): Promise<void> {
    if (this.connecting()) {
      return;
    }
    this.connecting.set(aspsp.name);
    this.error.set(null);
    try {
      this.redirect.go(await this.bank.connect(aspsp));
    } catch (error) {
      this.connecting.set(null);
      this.error.set(firstValidationMessage(error, 'No se ha podido iniciar la conexión con el banco.'));
    }
  }
}
