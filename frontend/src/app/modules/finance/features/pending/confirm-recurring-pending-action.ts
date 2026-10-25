import { ChangeDetectionStrategy, Component, inject, input, signal } from '@angular/core';
import { firstValidationMessage } from '@core/http/api';
import { PendingItem } from '@core/pending/pending.models';
import { PendingStore } from '@core/pending/pending.store';
import { UiButton } from '@ui/button/button';
import { DialogService } from '@ui/dialog/dialog.service';
import { ToastService } from '@ui/toast/toast.service';
import { firstValueFrom } from 'rxjs';
import { ConfirmRecurringResult } from '../../data-access/recurring.models';
import { RecurringService } from '../../data-access/recurring.service';
import { ConfirmOccurrenceDialog, ConfirmOccurrenceDialogData } from '../recurring/confirm-occurrence-dialog';

@Component({
  selector: 'fin-confirm-recurring-pending-action',
  imports: [UiButton],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <button ui-button type="button" variant="secondary" size="sm" icon="check" [loading]="loading()" (click)="confirm()">
      Confirmar cargo
    </button>
  `,
})
export class ConfirmRecurringPendingAction {
  private readonly recurring = inject(RecurringService);
  private readonly dialogs = inject(DialogService);
  private readonly pending = inject(PendingStore);
  private readonly toast = inject(ToastService);

  readonly item = input.required<PendingItem>();

  protected readonly loading = signal(false);

  protected async confirm(): Promise<void> {
    const item = this.item();
    const ruleId = item.meta['rule_id'];
    if (typeof ruleId !== 'string' || this.loading()) {
      return;
    }
    this.loading.set(true);
    let rule;
    try {
      rule = await this.recurring.get(ruleId);
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido cargar el recurrente.'));
      return;
    } finally {
      this.loading.set(false);
    }
    const ref = this.dialogs.open<ConfirmOccurrenceDialog, ConfirmOccurrenceDialogData, ConfirmRecurringResult>(
      ConfirmOccurrenceDialog,
      { data: { rule } },
    );
    const result = await firstValueFrom(ref.closed);
    if (result) {
      this.pending.resolve(item);
    }
  }
}
