import {
  booleanAttribute,
  ChangeDetectionStrategy,
  Component,
  computed,
  DestroyRef,
  effect,
  ElementRef,
  inject,
  input,
  signal,
  untracked,
  viewChild,
} from '@angular/core';
import { ThemeService } from '@core/theme/theme.service';
import { formatMoney, formatMoneyCompact } from '@shared/money/money';
import {
  ArcElement,
  BarController,
  BarElement,
  CategoryScale,
  Chart,
  ChartConfiguration,
  DoughnutController,
  Filler,
  LinearScale,
  LineController,
  LineElement,
  PointElement,
  Tooltip,
} from 'chart.js';
import { UiIcon } from '../icon/icon';

Chart.register(
  BarController,
  BarElement,
  LineController,
  LineElement,
  PointElement,
  DoughnutController,
  ArcElement,
  CategoryScale,
  LinearScale,
  Tooltip,
  Filler,
);

export type UiChartType = 'bar' | 'line' | 'doughnut';
export type UiChartSlot = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8;
export type UiChartColor = UiChartSlot | 'positive' | 'negative' | 'warning' | 'text' | 'text-2' | 'text-3';
export type UiChartValueFormat = 'money' | 'number' | 'percent';

export interface UiChartSeries {
  label: string;
  data: number[];
  color?: UiChartColor;
}

const numberFormatter = new Intl.NumberFormat('es-ES', { useGrouping: 'always', maximumFractionDigits: 2 });
const percentFormatter = new Intl.NumberFormat('es-ES', { style: 'percent', maximumFractionDigits: 1 });

export function formatChartValue(value: number, format: UiChartValueFormat): string {
  switch (format) {
    case 'money':
      return formatMoney(value);
    case 'percent':
      return percentFormatter.format(value);
    default:
      return numberFormatter.format(value);
  }
}

const formatAxisValue = (value: number, format: UiChartValueFormat): string =>
  format === 'money' ? formatMoneyCompact(value) : formatChartValue(value, format);

export const colorToken = (color: UiChartColor): string =>
  typeof color === 'number' ? `--c${color}` : `--${color}`;

const slotFor = (index: number): UiChartSlot => ((index % 8) + 1) as UiChartSlot;

@Component({
  selector: 'ui-chart',
  imports: [UiIcon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (showLegend() || tableToggle()) {
      <div class="toolbar" [class.toggle-only]="!showLegend() && type() === 'doughnut'">
        @if (showLegend()) {
          <ul class="legend" [attr.aria-label]="'Leyenda: ' + ariaLabel()">
            @for (entry of legend(); track $index) {
              <li>
                <span class="legend-swatch" [style.background]="'var(' + entry.token + ')'"></span>{{ entry.label }}
                @if (entry.value !== null) {
                  <span class="num legend-value">{{ entry.value }}</span>
                }
              </li>
            }
          </ul>
        }
        @if (tableToggle()) {
          <button
            type="button"
            class="toggle"
            [attr.aria-pressed]="showTable()"
            [attr.aria-label]="showTable() ? 'Ver como gráfico' : 'Ver como tabla'"
            (click)="showTable.set(!showTable())"
          >
            <ui-icon [name]="showTable() ? 'chart-column' : 'table'" [size]="16" />
          </button>
        }
      </div>
    }
    <div class="canvas-wrap" [hidden]="showTable()" [style.height.px]="height()">
      <canvas #canvas role="img" [attr.aria-label]="ariaLabel()"></canvas>
      @if (type() === 'doughnut' && (centerLabel() || centerValue())) {
        <div class="center" aria-hidden="true">
          <span class="center-label">{{ centerLabel() }}</span>
          <span class="center-value num">{{ centerValue() }}</span>
        </div>
      }
    </div>
    @if (showTable()) {
      <div class="table-wrap">
        <table>
          <caption class="sr-only">{{ ariaLabel() }}</caption>
          <thead>
            <tr>
              <th scope="col">{{ categoryHeader() }}</th>
              @for (series of series(); track $index) {
                <th scope="col" class="num-col">{{ series.label }}</th>
              }
            </tr>
          </thead>
          <tbody>
            @for (label of labels(); track $index; let row = $index) {
              <tr>
                <th scope="row">{{ label }}</th>
                @for (series of series(); track $index) {
                  <td class="num num-col">{{ format(series.data[row]) }}</td>
                }
              </tr>
            }
          </tbody>
        </table>
      </div>
    }
  `,
  styles: `
    :host {
      display: block;
      position: relative;
      min-width: 0;
    }
    .toolbar.toggle-only {
      position: absolute;
      top: 0;
      right: 0;
      z-index: 1;
      margin: 0;
    }
    .toolbar {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 12px;
    }
    .legend {
      list-style: none;
      margin: 0;
      padding: 0;
    }
    .legend-value {
      margin-left: 6px;
      color: var(--text);
    }
    .toggle {
      margin-left: auto;
      width: 32px;
      height: 32px;
      border-radius: 999px;
      border: 0;
      background: none;
      color: var(--text-2);
      display: grid;
      place-items: center;
      flex: none;
    }
    .toggle:hover,
    .toggle[aria-pressed='true'] {
      background: var(--surface-2);
      color: var(--text);
    }
    .canvas-wrap {
      position: relative;
      width: 100%;
    }
    .center {
      position: absolute;
      inset: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      pointer-events: none;
    }
    .center-label {
      font-size: 11px;
      color: var(--text-3);
    }
    .center-value {
      font-size: 15px;
      font-weight: 650;
      color: var(--text);
    }
    .table-wrap {
      overflow-x: auto;
    }
    table {
      width: 100%;
      font-size: 13px;
    }
    th,
    td {
      padding: 6px 8px;
      border-bottom: 1px solid var(--border);
      text-align: left;
      font-weight: 400;
    }
    thead th {
      color: var(--text-3);
      font-weight: 500;
    }
    .num-col {
      text-align: right;
    }
  `,
})
export class UiChart {
  private readonly theme = inject(ThemeService);
  private readonly canvas = viewChild<ElementRef<HTMLCanvasElement>>('canvas');
  private chart: Chart | null = null;

  readonly type = input.required<UiChartType>();
  readonly labels = input.required<string[]>();
  readonly series = input.required<UiChartSeries[]>();
  readonly ariaLabel = input.required<string>();
  readonly colors = input<readonly UiChartColor[] | null>(null);
  readonly valueFormat = input<UiChartValueFormat>('money');
  readonly height = input(220);
  readonly stacked = input(false, { transform: booleanAttribute });
  readonly showLegend = input(true, { transform: booleanAttribute });
  readonly legendValues = input(false, { transform: booleanAttribute });
  readonly tableToggle = input(true, { transform: booleanAttribute });
  readonly categoryHeader = input('Periodo');
  readonly centerLabel = input<string | null>(null);
  readonly centerValue = input<string | null>(null);

  protected readonly showTable = signal(false);
  protected readonly legend = computed(() => {
    if (this.type() === 'doughnut') {
      const data = this.series()[0]?.data ?? [];
      return this.labels().map((label, index) => ({
        label,
        token: colorToken(this.sliceColor(index)),
        value: this.legendValues() ? this.format(data[index]) : null,
      }));
    }
    return this.series().map((series, index) => ({
      label: series.label,
      token: colorToken(series.color ?? slotFor(index)),
      value: null,
    }));
  });

  constructor() {
    effect(() => {
      const canvas = this.canvas();
      this.theme.effective();
      const config = this.buildConfig();
      if (!canvas) {
        return;
      }
      untracked(() => this.render(canvas.nativeElement, config));
    });
    inject(DestroyRef).onDestroy(() => this.chart?.destroy());
  }

  protected format(value: number | undefined): string {
    return value === undefined || value === null ? '—' : formatChartValue(value, this.valueFormat());
  }

  private sliceColor(index: number): UiChartColor {
    return this.colors()?.[index] ?? slotFor(index);
  }

  private render(canvas: HTMLCanvasElement, config: ChartConfiguration): void {
    this.chart?.destroy();
    this.chart = new Chart(canvas, config);
  }

  private buildConfig(): ChartConfiguration {
    const styles = getComputedStyle(document.documentElement);
    const read = (token: string) => styles.getPropertyValue(token).trim() || '#888';
    const type = this.type();
    const format = this.valueFormat();
    const reducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
    const text3 = read('--text-3');
    const border = read('--border');
    const surface = read('--surface');
    const font = { family: read('--font-system') || 'system-ui', size: 11 };

    const datasets = this.series().map((series, index) => {
      const color = read(colorToken(series.color ?? slotFor(index)));
      if (type === 'doughnut') {
        return {
          label: series.label,
          data: series.data,
          backgroundColor: series.data.map((_, slice) => read(colorToken(this.sliceColor(slice)))),
          borderColor: surface,
          borderWidth: 2,
          hoverOffset: 4,
        };
      }
      if (type === 'line') {
        return {
          label: series.label,
          data: series.data,
          borderColor: color,
          backgroundColor: color,
          borderWidth: 2,
          tension: 0,
          pointRadius: series.data.map((_, point) => (point === series.data.length - 1 ? 4 : 0)),
          pointHoverRadius: 5,
          pointBorderColor: surface,
          pointBorderWidth: 2,
          fill: false,
        };
      }
      return {
        label: series.label,
        data: series.data,
        backgroundColor: color,
        borderRadius: 4,
        borderSkipped: 'start' as const,
        maxBarThickness: 14,
        categoryPercentage: 0.6,
        barPercentage: 0.9,
      };
    });

    const tooltip = {
      backgroundColor: read('--text'),
      titleColor: read('--bg'),
      bodyColor: read('--bg'),
      cornerRadius: 8,
      padding: 10,
      boxPadding: 4,
      titleFont: { ...font, size: 13, weight: 600 as const },
      bodyFont: { ...font, size: 13 },
      callbacks: {
        label: (context: { dataset: { label?: string }; parsed: number | { y: number }; label: string }) => {
          const raw = typeof context.parsed === 'number' ? context.parsed : context.parsed.y;
          const name = type === 'doughnut' ? context.label : (context.dataset.label ?? '');
          return `${name}: ${formatChartValue(raw, format)}`;
        },
      },
    };

    const base = {
      responsive: true,
      maintainAspectRatio: false,
      animation: reducedMotion ? (false as const) : { duration: 300 },
      plugins: { legend: { display: false }, tooltip },
      interaction: { mode: 'index' as const, intersect: false },
    };

    if (type === 'doughnut') {
      return {
        type: 'doughnut',
        data: { labels: this.labels(), datasets: datasets as ChartConfiguration<'doughnut'>['data']['datasets'] },
        options: { ...base, cutout: '68%', interaction: { mode: 'nearest', intersect: true } },
      } as ChartConfiguration;
    }

    const scales = {
      x: {
        stacked: this.stacked(),
        grid: { display: false },
        border: { display: false },
        ticks: { color: text3, font, maxRotation: 0, autoSkipPadding: 8 },
      },
      y: {
        stacked: this.stacked(),
        grid: { color: border },
        border: { display: false },
        ticks: {
          color: text3,
          font,
          maxTicksLimit: 5,
          callback: (value: string | number) => formatAxisValue(Number(value), format),
        },
      },
    };

    return {
      type,
      data: { labels: this.labels(), datasets },
      options: { ...base, scales },
    } as ChartConfiguration;
  }
}
