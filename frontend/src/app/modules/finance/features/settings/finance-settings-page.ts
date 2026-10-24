import { ChangeDetectionStrategy, Component } from '@angular/core';
import { UiPageHeader } from '@ui/page-header/page-header';
import { FinanceSettingsPanel } from './finance-settings-panel';

@Component({
  selector: 'app-finance-settings-page',
  imports: [UiPageHeader, FinanceSettingsPanel],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <ui-page-header heading="Ajustes de Finanzas" crumb="Finanzas" />
    <fin-settings-panel />
  `,
})
export class FinanceSettingsPage {}
