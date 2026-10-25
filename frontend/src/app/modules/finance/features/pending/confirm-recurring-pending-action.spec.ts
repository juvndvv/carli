import { HttpTestingController } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { PendingStore } from '@core/pending/pending.store';
import { aPendingItem } from '@core/pending/testing/pending-fixtures';
import { DialogService } from '@ui/dialog/dialog.service';
import { Subject } from 'rxjs';
import { RecurringRule } from '../../data-access/recurring.models';
import { configureFinanceTesting, pending, tick } from '../../testing/finance-testing';
import { ConfirmOccurrenceDialog } from '../recurring/confirm-occurrence-dialog';
import { ConfirmRecurringPendingAction } from './confirm-recurring-pending-action';

const item = aPendingItem({
  type: 'recurring_to_confirm',
  id: 'tx-r',
  title: 'Netflix',
  route: '/finanzas/recurrentes',
  meta: { transaction_id: 'tx-r', rule_id: 'netflix' },
});

const rule = { id: 'netflix', name: 'Netflix' } as RecurringRule;

describe('ConfirmRecurringPendingAction', () => {
  let http: HttpTestingController;
  let closed: Subject<unknown>;
  let open: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    http = configureFinanceTesting();
    closed = new Subject();
    open = vi.spyOn(TestBed.inject(DialogService), 'open').mockReturnValue({ closed } as never);
  });

  async function clickConfirm() {
    const fixture = TestBed.createComponent(ConfirmRecurringPendingAction);
    fixture.componentRef.setInput('item', item);
    await fixture.whenStable();
    (fixture.nativeElement as HTMLElement).querySelector<HTMLButtonElement>('button')!.click();
    pending(http, 'recurring-rules/netflix')[0].flush({ data: rule });
    await tick();
  }

  it('opens the confirm dialog with the rule and resolves the item once confirmed', async () => {
    const resolve = vi.spyOn(TestBed.inject(PendingStore), 'resolve');
    await clickConfirm();

    expect(open).toHaveBeenCalledWith(ConfirmOccurrenceDialog, { data: { rule } });
    closed.next({ rule, transaction: {}, price_changed: false });
    closed.complete();
    await tick();
    expect(resolve).toHaveBeenCalledWith(item);
  });

  it('leaves the item when the dialog is dismissed', async () => {
    const resolve = vi.spyOn(TestBed.inject(PendingStore), 'resolve');
    await clickConfirm();

    closed.next(undefined);
    closed.complete();
    await tick();
    expect(resolve).not.toHaveBeenCalled();
  });
});
