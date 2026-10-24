import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { firstValidationMessage } from '@core/http/api';
import { FinanceContact, FinanceContactDetail } from '@finance/data-access/contacts.models';
import { ContactsService } from '@finance/data-access/contacts.service';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiTextarea } from '@ui/textarea/textarea';
import { ToastService } from '@ui/toast/toast.service';

export interface ContactDialogData {
  contact: FinanceContact | null;
}

export type ContactDialogResult = FinanceContactDetail | 'deleted' | 'archived';

@Component({
  selector: 'app-finance-contact-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiInput, UiTextarea],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog [heading]="contact ? 'Editar contacto' : 'Nuevo contacto'" [subtitle]="contact ? null : 'Solo necesitas un nombre; no tendrá acceso a la app.'">
      <form [formGroup]="form" (ngSubmit)="save()" id="contact-form" class="form">
        <ui-field label="Nombre" for="contact-name" [error]="nameError() ? 'Escribe un nombre.' : null">
          <input ui-input id="contact-name" formControlName="name" placeholder="Ana, Piso compartido…" autocomplete="off" [invalid]="nameError()" />
        </ui-field>
        <ui-field label="Notas" for="contact-notes">
          <textarea ui-textarea id="contact-notes" rows="2" formControlName="notes" placeholder="Opcional"></textarea>
        </ui-field>
        @if (error()) {
          <p class="field-error" role="alert">{{ error() }}</p>
        }
      </form>
      <div dialog-footer class="footer">
        @if (contact) {
          @if (canDelete) {
            <button ui-button type="button" variant="ghost" icon="trash" class="danger-text" [disabled]="saving()" (click)="remove()">Eliminar</button>
          }
          <button ui-button type="button" variant="ghost" icon="archive" [disabled]="saving()" (click)="toggleArchive()">
            {{ contact.archived ? 'Desarchivar' : 'Archivar' }}
          </button>
        }
        <span class="spacer"></span>
        <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        <button ui-button type="submit" form="contact-form" variant="primary" [loading]="saving()">
          {{ contact ? 'Guardar' : 'Añadir contacto' }}
        </button>
      </div>
    </ui-dialog>
  `,
  styles: `
    .form {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .footer {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .spacer {
      flex: 1;
    }
    .danger-text {
      color: var(--negative);
    }
  `,
})
export class ContactDialog {
  protected readonly ref = inject<DialogRef<ContactDialogResult>>(DialogRef);
  private readonly data = inject<ContactDialogData>(DIALOG_DATA);
  private readonly service = inject(ContactsService);
  private readonly toast = inject(ToastService);
  private readonly router = inject(Router);

  protected readonly contact = this.data.contact;
  protected readonly canDelete = canDeleteContact(this.contact);

  protected readonly form = new FormGroup({
    name: new FormControl(this.contact?.name ?? '', { nonNullable: true, validators: [Validators.required, Validators.maxLength(120)] }),
    notes: new FormControl(this.contact?.notes ?? '', { nonNullable: true, validators: [Validators.maxLength(2000)] }),
  });

  protected readonly submitted = signal(false);
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  protected nameError(): boolean {
    return this.submitted() && this.form.controls.name.invalid;
  }

  async save(): Promise<void> {
    this.submitted.set(true);
    if (this.form.invalid || !this.form.controls.name.value.trim()) {
      this.form.controls.name.setErrors({ required: true });
      return;
    }
    const value = this.form.getRawValue();
    const payload = { name: value.name.trim(), notes: value.notes.trim() || null };
    this.saving.set(true);
    this.error.set(null);
    try {
      const saved = this.contact ? await this.service.update(this.contact.id, payload) : await this.service.create(payload);
      this.toast.show(this.contact ? 'Contacto actualizado' : `${saved.name} añadido`);
      this.ref.close(saved);
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido guardar el contacto.'));
    } finally {
      this.saving.set(false);
    }
  }

  protected async toggleArchive(): Promise<void> {
    if (!this.contact) {
      return;
    }
    const contact = this.contact;
    const archived = !contact.archived;
    this.saving.set(true);
    try {
      await this.service.update(contact.id, { archived });
      if (archived) {
        this.toast.withUndo(`${contact.name} archivado`, () => this.service.update(contact.id, { archived: false }));
      }
      this.ref.close('archived');
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se ha podido archivar el contacto.'));
    } finally {
      this.saving.set(false);
    }
  }

  protected async remove(): Promise<void> {
    if (!this.contact) {
      return;
    }
    const contact = this.contact;
    this.saving.set(true);
    try {
      await this.service.remove(contact.id);
      this.toast.withUndo(`${contact.name} eliminado`, () => this.service.create({ name: contact.name, notes: contact.notes }));
      this.ref.close('deleted');
      await this.router.navigateByUrl('/finanzas/compartidos');
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'Este contacto tiene gastos o deudas: archívalo en su lugar.'));
    } finally {
      this.saving.set(false);
    }
  }
}

export function canDeleteContact(contact: FinanceContact | FinanceContactDetail | null): boolean {
  if (!contact || !('shares' in contact)) {
    return false;
  }
  return contact.shares.length === 0 && contact.debts.length === 0;
}
