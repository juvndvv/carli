import { booleanAttribute, ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { UiIcon } from '../icon/icon';

export type ProgressState = 'ok' | 'warn' | 'over';
export type ProgressTone = 'status' | 'primary';

export function progressState(ratio: number, warnAt = 0.8): ProgressState {
  if (ratio > 1) {
    return 'over';
  }
  return ratio >= warnAt ? 'warn' : 'ok';
}

const STATE_ICONS: Record<ProgressState, string> = { ok: 'circle-check', warn: 'triangle-alert', over: 'circle-x' };
const STATE_LABELS: Record<ProgressState, string> = { ok: 'En margen', warn: 'Cerca del límite', over: 'Excedido' };

@Component({
  selector: 'ui-progress',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[class]': "'state-' + state() + ' tone-' + tone()" },
  template: `
    <div
      class="track"
      role="progressbar"
      aria-valuemin="0"
      [attr.aria-valuemax]="100"
      [attr.aria-valuenow]="percent()"
      [attr.aria-valuetext]="percent() + ' %' + (tone() === 'status' ? ', ' + stateLabel() : '')"
      [attr.aria-label]="label()"
    >
      <span class="fill" [style.width.%]="fillWidth()"></span>
    </div>
    @if (showStatus()) {
      <div class="status small">
        <ui-icon [name]="stateIcon()" [size]="14" />
        <span>{{ statusText() ?? stateLabel() + ' · ' + percent() + ' %' }}</span>
      </div>
    }
  `,
  styles: `
    :host {
      display: block;
    }
    .track {
      height: 8px;
      border-radius: 999px;
      background: var(--surface-2);
      overflow: hidden;
    }
    .fill {
      display: block;
      height: 100%;
      border-radius: 999px;
      background: var(--text);
      transition: width var(--motion-enter) ease-out;
    }
    :host(.tone-primary) .fill {
      background: var(--primary-strong);
    }
    :host(.tone-status.state-warn) .fill {
      background: var(--warning);
    }
    :host(.tone-status.state-over) .fill {
      background: var(--negative);
    }
    .status {
      display: flex;
      align-items: center;
      gap: 4px;
      margin-top: 4px;
      color: var(--text-2);
    }
    :host(.tone-status.state-warn) .status {
      color: var(--warning);
    }
    :host(.tone-status.state-over) .status {
      color: var(--negative);
    }
  `,
})
export class UiProgress {
  readonly value = input<number | null>(null);
  readonly max = input<number | null>(null);
  readonly ratio = input<number | null>(null);
  readonly warnAt = input(0.8);
  readonly tone = input<ProgressTone>('status');
  readonly label = input<string | null>(null);
  readonly showStatus = input(false, { transform: booleanAttribute });
  readonly statusText = input<string | null>(null);

  protected readonly computedRatio = computed(() => {
    const ratio = this.ratio();
    if (ratio !== null) {
      return ratio;
    }
    const max = this.max();
    return max ? (this.value() ?? 0) / max : 0;
  });
  protected readonly state = computed(() => progressState(this.computedRatio(), this.warnAt()));
  protected readonly percent = computed(() => Math.round(this.computedRatio() * 100));
  protected readonly fillWidth = computed(() => Math.min(Math.max(this.computedRatio(), 0), 1) * 100);
  protected readonly stateIcon = computed(() => STATE_ICONS[this.state()]);
  protected readonly stateLabel = computed(() => STATE_LABELS[this.state()]);
}
