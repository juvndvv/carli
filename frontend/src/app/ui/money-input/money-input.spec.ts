import { Component, provideZonelessChangeDetection, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { UiMoneyInput } from './money-input';

@Component({
  imports: [UiMoneyInput, ReactiveFormsModule],
  template: `<ui-money-input [formControl]="control" [sign]="sign()" />`,
})
class HostComponent {
  readonly control = new FormControl<number | null>(null);
  readonly sign = signal<'none' | 'negative' | 'positive'>('negative');
}

describe('UiMoneyInput', () => {
  async function setup() {
    TestBed.configureTestingModule({ providers: [provideZonelessChangeDetection()] });
    const fixture = TestBed.createComponent(HostComponent);
    await fixture.whenStable();
    const input = fixture.nativeElement.querySelector('input') as HTMLInputElement;
    const type = async (text: string) => {
      input.value = text;
      input.dispatchEvent(new Event('input'));
      await fixture.whenStable();
    };
    return { fixture, input, type, host: fixture.componentInstance };
  }

  it('uses a decimal keyboard on mobile', async () => {
    const { input } = await setup();
    expect(input.getAttribute('inputmode')).toBe('decimal');
  });

  it('emits integer cents for comma decimals', async () => {
    const { type, host } = await setup();
    await type('42,50');
    expect(host.control.value).toBe(4250);
    await type('1.234,5');
    expect(host.control.value).toBe(123450);
  });

  it('emits null and flags invalid text', async () => {
    const { type, host, fixture } = await setup();
    await type('12,345');
    expect(host.control.value).toBeNull();
    expect(fixture.nativeElement.querySelector('ui-money-input').classList).toContain('invalid');
  });

  it('rejects negative amounts unless allowed', async () => {
    const { type, host } = await setup();
    await type('-5');
    expect(host.control.value).toBeNull();
  });

  it('shows grouped text for values written by the form', async () => {
    const { host, input, fixture } = await setup();
    host.control.setValue(269500);
    await fixture.whenStable();
    expect(input.value).toBe('2.695,00');
  });

  it('renders the sign prefix for expenses', async () => {
    const { fixture } = await setup();
    expect(fixture.nativeElement.querySelector('.sign').textContent).toBe('−');
  });
});
