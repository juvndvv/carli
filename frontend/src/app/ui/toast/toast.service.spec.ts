import { TestBed } from '@angular/core/testing';
import { ToastService } from './toast.service';

describe('ToastService', () => {
  let toasts: ToastService;

  beforeEach(() => {
    vi.useFakeTimers();
    toasts = TestBed.inject(ToastService);
  });

  afterEach(() => vi.useRealTimers());

  const messages = () => toasts.active().map((toast) => toast.message);

  it('replaces the current toast when showing a new one', () => {
    toasts.show('Primero');
    toasts.show('Segundo');
    expect(messages()).toEqual(['Segundo']);
  });

  it('shows a queued toast right away when nothing actionable is on screen', () => {
    toasts.show('Cambios guardados');
    toasts.enqueue('Hay 2 parecidos');
    expect(messages()).toEqual(['Hay 2 parecidos']);
  });

  it('waits for an undo toast to go away before showing a queued one', () => {
    toasts.withUndo('Movimiento categorizado', () => undefined);
    toasts.enqueue({ message: 'Hay 2 parecidos', duration: 10000 });
    expect(messages()).toEqual(['Movimiento categorizado']);

    vi.advanceTimersByTime(5000);
    expect(messages()).toEqual(['Hay 2 parecidos']);

    vi.advanceTimersByTime(10000);
    expect(messages()).toEqual([]);
  });

  it('drops queued toasts when the user takes the action', async () => {
    const undo = vi.fn();
    toasts.withUndo('Movimiento categorizado', undo);
    toasts.enqueue('Hay 2 parecidos');

    await toasts.runAction(toasts.active()[0].id);

    expect(undo).toHaveBeenCalled();
    expect(messages()).toEqual([]);
  });

  it('cancels a queued toast through its handle', () => {
    const undoToast = toasts.withUndo('Movimiento categorizado', () => undefined);
    toasts.enqueue('Hay 2 parecidos').dismiss();
    undoToast.dismiss();
    expect(messages()).toEqual([]);
  });
});
