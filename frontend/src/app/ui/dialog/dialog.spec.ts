import { Component } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { UiDialog } from './dialog';
import { DialogService } from './dialog.service';

@Component({
  imports: [UiDialog],
  template: `
    <ui-dialog heading="Nueva cuenta">
      <label for="name">Nombre</label>
      <input id="name" />
      <div dialog-footer><button type="button">Guardar</button></div>
    </ui-dialog>
  `,
})
class FormDialog {}

@Component({
  imports: [UiDialog],
  template: `
    <ui-dialog heading="Movimiento">
      <input id="first" />
      <input id="amount" cdkFocusInitial />
    </ui-dialog>
  `,
})
class InitialFocusDialog {}

@Component({
  imports: [UiDialog],
  template: `
    <ui-dialog heading="¿Seguro?">
      <p>Texto</p>
      <div dialog-footer><button id="cancel" type="button">Cancelar</button></div>
    </ui-dialog>
  `,
})
class FooterOnlyDialog {}

describe('UiDialog initial focus', () => {
  async function openAndSettle(component: new () => unknown): Promise<Element | null> {
    const service = TestBed.inject(DialogService);
    service.open(component, { presentation: 'dialog' });
    TestBed.tick();
    await new Promise((resolve) => setTimeout(resolve));
    TestBed.tick();
    const active = document.activeElement;
    service.closeAll();
    return active;
  }

  it('focuses the first field instead of the close button', async () => {
    const active = await openAndSettle(FormDialog);
    expect(active?.id).toBe('name');
  });

  it('honours cdkFocusInitial', async () => {
    const active = await openAndSettle(InitialFocusDialog);
    expect(active?.id).toBe('amount');
  });

  it('falls back to the footer actions when the body has no fields', async () => {
    const active = await openAndSettle(FooterOnlyDialog);
    expect(active?.id).toBe('cancel');
  });
});
