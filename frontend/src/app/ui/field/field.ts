import { ChangeDetectionStrategy, Component, input } from '@angular/core';

@Component({
  selector: 'ui-field',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'field' },
  template: `
    @if (label()) {
      <label class="field-label" [attr.for]="for()">{{ label() }}</label>
    }
    <ng-content />
    @if (error()) {
      <span class="field-error" role="alert">{{ error() }}</span>
    } @else if (hint()) {
      <span class="field-hint">{{ hint() }}</span>
    }
  `,
})
export class UiField {
  readonly label = input<string | null>(null);
  readonly for = input<string | null>(null);
  readonly hint = input<string | null>(null);
  readonly error = input<string | null>(null);
}
