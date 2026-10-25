import { Injectable, signal } from '@angular/core';

export interface ToastAction {
  label: string;
  handler: () => unknown;
}

export interface ToastOptions {
  message: string;
  action?: ToastAction;
  duration?: number;
  tone?: 'default' | 'error';
}

export interface ActiveToast extends Required<Pick<ToastOptions, 'message' | 'duration' | 'tone'>> {
  id: number;
  action?: ToastAction;
}

export interface ToastHandle {
  dismiss: () => void;
}

export const DEFAULT_TOAST_DURATION = 5000;

@Injectable({ providedIn: 'root' })
export class ToastService {
  private readonly toasts = signal<ActiveToast[]>([]);
  private readonly timers = new Map<number, ReturnType<typeof setTimeout>>();
  private queue: { id: number; options: ToastOptions }[] = [];
  private nextId = 1;

  readonly active = this.toasts.asReadonly();

  show(options: ToastOptions | string): ToastHandle {
    return this.display(this.nextId++, normalize(options));
  }

  enqueue(options: ToastOptions | string): ToastHandle {
    if (!this.toasts()[0]?.action) {
      return this.show(options);
    }
    const id = this.nextId++;
    this.queue.push({ id, options: normalize(options) });
    return { dismiss: () => this.dismiss(id) };
  }

  withUndo(message: string, undo: () => unknown, duration = DEFAULT_TOAST_DURATION): ToastHandle {
    return this.show({ message, duration, action: { label: 'Deshacer', handler: undo } });
  }

  error(message: string): ToastHandle {
    return this.show({ message, tone: 'error' });
  }

  async runAction(id: number): Promise<void> {
    const toast = this.toasts().find((item) => item.id === id);
    this.queue = [];
    this.dismiss(id);
    await toast?.action?.handler();
  }

  dismiss(id: number): void {
    const timer = this.timers.get(id);
    if (timer) {
      clearTimeout(timer);
      this.timers.delete(id);
    }
    this.queue = this.queue.filter((queued) => queued.id !== id);
    this.toasts.update((toasts) => toasts.filter((toast) => toast.id !== id));
    const next = this.toasts().length === 0 ? this.queue.shift() : undefined;
    if (next) {
      this.display(next.id, next.options);
    }
  }

  private display(id: number, options: ToastOptions): ToastHandle {
    const toast: ActiveToast = {
      id,
      message: options.message,
      action: options.action,
      duration: options.duration ?? DEFAULT_TOAST_DURATION,
      tone: options.tone ?? 'default',
    };
    this.toasts.set([toast]);
    this.clearTimers();
    if (toast.duration > 0) {
      this.timers.set(
        toast.id,
        setTimeout(() => this.dismiss(toast.id), toast.duration),
      );
    }
    return { dismiss: () => this.dismiss(toast.id) };
  }

  private clearTimers(): void {
    this.timers.forEach((timer) => clearTimeout(timer));
    this.timers.clear();
  }
}

function normalize(options: ToastOptions | string): ToastOptions {
  return typeof options === 'string' ? { message: options } : options;
}
