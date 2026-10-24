import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { FormControl, ReactiveFormsModule, Validators } from '@angular/forms';
import { firstValidationMessage } from '@core/http/api';
import { UiButton } from '@ui/button/button';
import { UiDialog } from '@ui/dialog/dialog';
import { UiField } from '@ui/field/field';
import { UiInput } from '@ui/input/input';
import { UiSelect } from '@ui/select/select';
import { UiSelectOption } from '@ui/select/select-option';
import { Tag } from '../../data-access/finance.models';
import { normalizeTagName, TagsService } from '../../data-access/tags.service';

export interface TagDialogData {
  tag: Tag;
}

@Component({
  selector: 'fin-rename-tag-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiInput],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog heading="Renombrar etiqueta" [subtitle]="'#' + tag.name">
      <form class="stack" (submit)="$event.preventDefault(); save()">
        <ui-field label="Nuevo nombre" for="fin-tag-name" [error]="error()">
          <input ui-input id="fin-tag-name" autocomplete="off" [formControl]="name" />
        </ui-field>
        <div class="row between">
          <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
          <button ui-button type="submit" variant="primary" [loading]="saving()" [disabled]="name.invalid">Guardar</button>
        </div>
      </form>
    </ui-dialog>
  `,
})
export class RenameTagDialog {
  protected readonly tag = inject<TagDialogData>(DIALOG_DATA).tag;
  protected readonly ref = inject<DialogRef<Tag>>(DialogRef);
  private readonly tags = inject(TagsService);
  protected readonly name = new FormControl(this.tag.name, { nonNullable: true, validators: [Validators.required] });
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  protected async save(): Promise<void> {
    const name = normalizeTagName(this.name.value);
    if (!name || name === this.tag.name) {
      this.ref.close();
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      this.ref.close(await this.tags.rename(this.tag.id, name));
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'Ya existe una etiqueta con ese nombre: fusiónalas.'));
    } finally {
      this.saving.set(false);
    }
  }
}

@Component({
  selector: 'fin-merge-tag-dialog',
  imports: [ReactiveFormsModule, UiDialog, UiButton, UiField, UiSelect],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-dialog heading="Fusionar etiqueta" [subtitle]="'#' + tag.name + ' desaparecerá y sus movimientos pasarán a la elegida.'">
      <ui-field label="Fusionar con" for="fin-tag-merge">
        <ui-select inputId="fin-tag-merge" placeholder="Elige una etiqueta" [options]="targets()" [formControl]="target" />
      </ui-field>
      @if (error()) {
        <p class="field-error" role="alert">{{ error() }}</p>
      }
      <div class="row between">
        <button ui-button type="button" variant="ghost" (click)="ref.close()">Cancelar</button>
        <button ui-button type="button" variant="primary" icon="git-merge" [loading]="saving()" [disabled]="!target.value" (click)="merge()">
          Fusionar
        </button>
      </div>
    </ui-dialog>
  `,
})
export class MergeTagDialog {
  protected readonly tag = inject<TagDialogData>(DIALOG_DATA).tag;
  protected readonly ref = inject<DialogRef<Tag>>(DialogRef);
  private readonly tags = inject(TagsService);
  protected readonly target = new FormControl<string | null>(null);
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly targets = computed<UiSelectOption<string>[]>(() =>
    this.tags
      .all()
      .filter((candidate) => candidate.id !== this.tag.id)
      .map((candidate) => ({ value: candidate.id, label: `#${candidate.name}` })),
  );

  protected async merge(): Promise<void> {
    if (!this.target.value) {
      return;
    }
    this.saving.set(true);
    this.error.set(null);
    try {
      this.ref.close(await this.tags.merge(this.tag.id, this.target.value));
    } catch (error) {
      this.error.set(firstValidationMessage(error, 'No se han podido fusionar las etiquetas.'));
    } finally {
      this.saving.set(false);
    }
  }
}
