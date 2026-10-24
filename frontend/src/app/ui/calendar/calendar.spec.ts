import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { UiCalendar } from './calendar';

@Component({
  imports: [UiCalendar],
  template: `<ui-calendar [value]="value()" (picked)="value.set($event)" />`,
})
class CalendarHost {
  readonly value = signal<string | null>('2026-10-01');
}

describe('UiCalendar', () => {
  async function render() {
    const fixture = TestBed.createComponent(CalendarHost);
    document.body.appendChild(fixture.nativeElement);
    await fixture.whenStable();
    return { fixture, element: fixture.nativeElement as HTMLElement };
  }

  function press(element: HTMLElement, key: string): void {
    element.querySelector('[role="grid"]')!.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true }));
  }

  it('exposes a grid made of rows with readable day names', async () => {
    const { element } = await render();
    const rows = element.querySelectorAll('[role="grid"] > [role="row"]');
    expect(rows.length).toBe(7);
    expect(rows[0].querySelectorAll('[role="columnheader"]').length).toBe(7);
    expect(rows[1].querySelectorAll('[role="gridcell"]').length).toBe(7);
    const selected = element.querySelector<HTMLButtonElement>('button[data-iso="2026-10-01"]')!;
    expect(selected.getAttribute('aria-label')).toBe('1 de octubre de 2026');
    expect(selected.textContent!.trim()).toBe('1');
    expect(selected.closest('[role="gridcell"]')!.getAttribute('aria-selected')).toBe('true');
  });

  it('keeps a single tab stop and moves it with the arrow keys', async () => {
    const { fixture, element } = await render();
    const tabbable = () => Array.from(element.querySelectorAll<HTMLButtonElement>('button.day')).filter((b) => b.tabIndex === 0);
    expect(tabbable().map((button) => button.dataset['iso'])).toEqual(['2026-10-01']);

    press(element, 'ArrowRight');
    await fixture.whenStable();
    expect(tabbable().map((button) => button.dataset['iso'])).toEqual(['2026-10-02']);
    expect(document.activeElement).toBe(tabbable()[0]);

    press(element, 'ArrowUp');
    await fixture.whenStable();
    expect(tabbable()[0].dataset['iso']).toBe('2026-09-25');
    expect(element.textContent).toContain('septiembre 2026');

    press(element, 'End');
    await fixture.whenStable();
    expect(tabbable()[0].dataset['iso']).toBe('2026-09-27');

    press(element, 'PageDown');
    await fixture.whenStable();
    expect(tabbable()[0].dataset['iso']).toBe('2026-10-27');
  });

  it('emits the picked day', async () => {
    const { fixture, element } = await render();
    element.querySelector<HTMLButtonElement>('button[data-iso="2026-10-15"]')!.click();
    await fixture.whenStable();
    expect(fixture.componentInstance.value()).toBe('2026-10-15');
  });
});
