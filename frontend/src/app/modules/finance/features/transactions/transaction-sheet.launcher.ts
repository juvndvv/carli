import { inject, Injectable, Injector } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import type { Transaction } from '../../data-access/finance.models';
import type { TransactionSheetData, TransactionSheetPreset, TransactionSheetResult } from './transaction-form';

@Injectable({ providedIn: 'root' })
export class TransactionSheetLauncher {
  private readonly injector = inject(Injector);
  private active: { close: () => void } | null = null;

  async create(preset: TransactionSheetPreset = {}): Promise<TransactionSheetResult | undefined> {
    return this.open({ preset });
  }

  async edit(transaction: Transaction): Promise<TransactionSheetResult | undefined> {
    return this.open({ transaction });
  }

  async duplicate(transaction: Transaction): Promise<TransactionSheetResult | undefined> {
    return this.open({ duplicateOf: transaction });
  }

  async open(data: TransactionSheetData): Promise<TransactionSheetResult | undefined> {
    const [{ TransactionSheet }, { DialogService }] = await Promise.all([
      import('./transaction-sheet'),
      import('@ui/dialog/dialog.service'),
    ]);
    const dialogs = this.injector.get(DialogService);
    this.active?.close();
    const ref = dialogs.open<InstanceType<typeof TransactionSheet>, TransactionSheetData, TransactionSheetResult>(
      TransactionSheet,
      {
        data,
        presentation: 'auto',
        ariaLabel: data.transaction ? 'Editar movimiento' : 'Nuevo movimiento',
      },
    );
    this.active = ref;
    const result = await firstValueFrom(ref.closed);
    if (this.active === ref) {
      this.active = null;
    }
    if (result?.action === 'duplicate') {
      return this.duplicate(result.transaction);
    }
    return result;
  }
}
