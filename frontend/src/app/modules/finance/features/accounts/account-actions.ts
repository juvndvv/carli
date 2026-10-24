import { inject, Injectable } from '@angular/core';
import { firstValidationMessage } from '@core/http/api';
import { DialogService } from '@ui/dialog/dialog.service';
import { ToastService } from '@ui/toast/toast.service';
import { firstValueFrom } from 'rxjs';
import { AccountsService } from '../../data-access/accounts.service';
import { Account, ReconcileResult } from '../../data-access/finance.models';
import { AccountFormData, AccountFormDialog } from './account-form-dialog';
import { ReconcileData, ReconcileDialog } from './reconcile-dialog';

@Injectable({ providedIn: 'root' })
export class AccountActions {
  private readonly dialogs = inject(DialogService);
  private readonly accounts = inject(AccountsService);
  private readonly toast = inject(ToastService);

  async edit(account: Account | null = null): Promise<Account | undefined> {
    const ref = this.dialogs.open<AccountFormDialog, AccountFormData, Account>(AccountFormDialog, { data: { account } });
    const saved = await firstValueFrom(ref.closed);
    if (saved) {
      this.toast.show(account ? 'Cuenta actualizada' : 'Cuenta creada');
    }
    return saved;
  }

  async reconcile(account: Account): Promise<ReconcileResult | undefined> {
    const ref = this.dialogs.open<ReconcileDialog, ReconcileData, ReconcileResult>(ReconcileDialog, { data: { account } });
    return firstValueFrom(ref.closed);
  }

  async setArchived(account: Account, archived: boolean): Promise<void> {
    try {
      await this.accounts.update(account.id, { archived });
      this.toast.withUndo(archived ? `${account.name} archivada` : `${account.name} vuelve a estar activa`, () =>
        this.accounts.update(account.id, { archived: !archived }),
      );
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido actualizar la cuenta.'));
    }
  }

  async setIncludedInNetWorth(account: Account, include: boolean): Promise<void> {
    try {
      await this.accounts.update(account.id, { include_in_net_worth: include });
      this.toast.withUndo(include ? `${account.name} suma al patrimonio` : `${account.name} ya no suma al patrimonio`, () =>
        this.accounts.update(account.id, { include_in_net_worth: !include }),
      );
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'No se ha podido actualizar la cuenta.'));
    }
  }

  async remove(account: Account): Promise<boolean> {
    const confirmed = await this.dialogs.confirm({
      title: `¿Eliminar ${account.name}?`,
      message: 'Solo se pueden eliminar cuentas sin movimientos. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      danger: true,
    });
    if (!confirmed) {
      return false;
    }
    try {
      await this.accounts.remove(account.id);
      this.toast.show('Cuenta eliminada');
      return true;
    } catch (error) {
      this.toast.error(firstValidationMessage(error, 'Tiene movimientos: archívala en lugar de eliminarla.'));
      return false;
    }
  }
}
