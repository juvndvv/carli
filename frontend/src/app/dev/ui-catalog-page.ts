import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ThemePreference } from '@core/auth/auth.models';
import { ThemeService } from '@core/theme/theme.service';
import { MoneyPipe } from '@shared/money/money.pipe';
import { RelativeDatePipe } from '@shared/dates/relative-date.pipe';
import { addDays, todayIso } from '@shared/dates/dates';
import { periodLabel } from '@shared/periods/periods';
import { UiAvatar } from '@ui/avatar/avatar';
import { UiBadge } from '@ui/badge/badge';
import { UiButton } from '@ui/button/button';
import { UiCard } from '@ui/card/card';
import { UiCategoryOption, UiCategoryPicker } from '@ui/category-picker/category-picker';
import { UiChart, UiChartSeries } from '@ui/chart/chart';
import { UiChip } from '@ui/chip/chip';
import { UiCombobox } from '@ui/combobox/combobox';
import { UiDatePicker } from '@ui/date-picker/date-picker';
import { DialogService } from '@ui/dialog/dialog.service';
import { UiEmptyState } from '@ui/empty-state/empty-state';
import { UiField } from '@ui/field/field';
import { UiIcon } from '@ui/icon/icon';
import { UiInput } from '@ui/input/input';
import { UiListItem } from '@ui/list-item/list-item';
import { UiMoneyInput } from '@ui/money-input/money-input';
import { UiProgress } from '@ui/progress/progress';
import { UiSearch } from '@ui/search/search';
import { UiSegmented, UiSegmentedOption } from '@ui/segmented/segmented';
import { UiSelect } from '@ui/select/select';
import { UiSelectOption } from '@ui/select/select-option';
import { UiSkeleton } from '@ui/skeleton/skeleton';
import { UiStat } from '@ui/stat/stat';
import { UiSwitch } from '@ui/switch/switch';
import { UiTab, UiTabs } from '@ui/tabs/tabs';
import { UiTextarea } from '@ui/textarea/textarea';
import { ToastService } from '@ui/toast/toast.service';
import { UiTooltip } from '@ui/tooltip/tooltip';
import { CatalogDialogExample } from './catalog-dialog-example';

const SURFACE_TOKENS = ['bg', 'surface', 'surface-2', 'sidebar', 'border', 'text', 'text-2', 'text-3'];
const STATUS_TOKENS = ['positive', 'warning', 'negative', 'primary'];
const MONTHS = ['nov', 'dic', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct'];

@Component({
  selector: 'app-ui-catalog-page',
  imports: [
    FormsModule,
    RouterLink,
    MoneyPipe,
    RelativeDatePipe,
    UiAvatar,
    UiBadge,
    UiButton,
    UiCard,
    UiCategoryPicker,
    UiChart,
    UiChip,
    UiCombobox,
    UiDatePicker,
    UiEmptyState,
    UiField,
    UiIcon,
    UiInput,
    UiListItem,
    UiMoneyInput,
    UiProgress,
    UiSearch,
    UiSegmented,
    UiSelect,
    UiSkeleton,
    UiStat,
    UiSwitch,
    UiTabs,
    UiTextarea,
    UiTooltip,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './ui-catalog-page.html',
  styleUrl: './ui-catalog-page.css',
})
export class UiCatalogPage {
  protected readonly theme = inject(ThemeService);
  private readonly toast = inject(ToastService);
  private readonly dialogs = inject(DialogService);

  protected readonly surfaceTokens = SURFACE_TOKENS;
  protected readonly statusTokens = STATUS_TOKENS;
  protected readonly categoricalSlots = [1, 2, 3, 4, 5, 6, 7, 8];
  protected readonly today = todayIso();
  protected readonly yesterday = addDays(this.today, -1);
  protected readonly lastWeek = addDays(this.today, -2);
  protected readonly samplePeriod = periodLabel({ start_date: '2026-10-28', end_date: '2026-11-26' });

  protected readonly themeOptions: UiSegmentedOption<ThemePreference>[] = [
    { value: 'light', label: 'Claro', icon: 'sun' },
    { value: 'dark', label: 'Oscuro', icon: 'moon' },
    { value: 'system', label: 'Sistema', icon: 'monitor' },
  ];
  protected readonly kindOptions: UiSegmentedOption[] = [
    { value: 'expense', label: 'Gasto' },
    { value: 'income', label: 'Ingreso' },
    { value: 'transfer', label: 'Transferencia' },
  ];
  protected readonly accountOptions: UiSelectOption[] = [
    { value: 'checking', label: 'Cuenta corriente', icon: 'landmark', description: 'BBVA' },
    { value: 'savings', label: 'Ahorro', icon: 'piggy-bank', description: 'ING Cuenta Naranja' },
    { value: 'card', label: 'Visa Oro', icon: 'credit-card', description: 'BBVA' },
    { value: 'cash', label: 'Efectivo', icon: 'banknote' },
  ];
  protected readonly payeeOptions: UiSelectOption[] = [
    { value: 'mercadona', label: 'Mercadona', icon: 'shopping-cart', description: 'Alimentación' },
    { value: 'repsol', label: 'Gasolinera Repsol', icon: 'car', description: 'Transporte' },
    { value: 'spotify', label: 'Spotify', icon: 'repeat', description: 'Suscripciones' },
    { value: 'zara', label: 'Zara', icon: 'shirt', description: 'Ropa' },
  ];
  protected readonly categories: UiCategoryOption[] = [
    { id: 'home', name: 'Vivienda', icon: 'house' },
    { id: 'food', name: 'Alimentación', icon: 'shopping-cart' },
    { id: 'transport', name: 'Transporte', icon: 'car' },
    { id: 'leisure', name: 'Ocio', icon: 'party-popper' },
    { id: 'health', name: 'Salud', icon: 'heart-pulse' },
    { id: 'subscriptions', name: 'Suscripciones', icon: 'repeat' },
    { id: 'clothes', name: 'Ropa', icon: 'shirt' },
    { id: 'restaurants', name: 'Restaurantes', icon: 'utensils' },
  ];
  protected readonly tabs: UiTab[] = [
    { id: 'all', label: 'Todos' },
    { id: 'subscriptions', label: 'Suscripciones' },
    { id: 'pending', label: 'Pendientes de confirmar', badge: 1 },
    { id: 'cancelled', label: 'Canceladas' },
  ];

  protected readonly months = MONTHS;
  protected readonly incomeExpenses: UiChartSeries[] = [
    {
      label: 'Ingresos',
      color: 1,
      data: [265000, 412000, 265000, 265000, 271000, 265000, 265000, 398000, 265000, 265000, 272000, 269500],
    },
    {
      label: 'Gastos',
      color: 2,
      data: [198000, 286000, 231000, 205000, 219500, 224000, 209000, 251000, 276000, 302000, 214000, 175527],
    },
  ];
  protected readonly netWorth: UiChartSeries[] = [
    {
      label: 'Patrimonio',
      color: 1,
      data: [1180000, 1220000, 1251000, 1290000, 1322000, 1356000, 1381000, 1418000, 1405000, 1431000, 1462722, 1556695],
    },
  ];
  protected readonly spendingLabels = ['Vivienda', 'Alimentación', 'Restaurantes', 'Ocio', 'Transporte', 'Ropa'];
  protected readonly spending: UiChartSeries[] = [
    { label: 'Gastado', data: [91340, 31260, 16450, 10200, 9850, 5995] },
  ];
  protected readonly spendingColors = [1, 2, 8, 4, 3, 7] as const;

  protected readonly amount = signal<number | null>(4250);
  protected readonly kind = signal<string | null>('expense');
  protected readonly account = signal<string | null>('card');
  protected readonly payee = signal<string | null>(null);
  protected readonly category = signal<string | null>('food');
  protected readonly date = signal<string | null>(this.today);
  protected readonly search = signal('');
  protected readonly switchOn = signal(true);
  protected readonly tab = signal<string | null>('all');
  protected readonly chipOn = signal(true);

  protected setTheme(preference: ThemePreference | null): void {
    if (preference) {
      this.theme.set(preference);
    }
  }

  protected showToast(): void {
    this.toast.withUndo('Movimiento borrado', () => this.toast.show('Movimiento restaurado'));
  }

  protected showErrorToast(): void {
    this.toast.error('No se ha podido guardar');
  }

  protected openDialog(): void {
    this.dialogs.open(CatalogDialogExample);
  }

  protected openSheet(): void {
    this.dialogs.openSheet(CatalogDialogExample);
  }

  protected async openConfirm(): Promise<void> {
    const confirmed = await this.dialogs.confirm({
      title: 'Borrar la cuenta',
      message: 'La cuenta tiene movimientos: se archivará en lugar de borrarse.',
      confirmLabel: 'Archivar',
      danger: true,
    });
    this.toast.show(confirmed ? 'Confirmado' : 'Cancelado');
  }
}
