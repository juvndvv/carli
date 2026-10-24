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
  private nextId = 1;

  readonly active = this.toasts.asReadonly();

  show(options: ToastOptions | string): ToastHandle {
    const normalized = typeof options === 'string' ? { message: options } : options;
    const toast: ActiveToast = {
      id: this.nextId++,
      message: normalized.message,
      action: normalized.action,
      duration: normalized.duration ?? DEFAULT_TOAST_DURATION,
      tone: normalized.tone ?? 'default',
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

  withUndo(message: string, undo: () => unknown, duration = DEFAULT_TOAST_DURATION): ToastHandle {
    return this.show({ message, duration, action: { label: 'Deshacer', handler: undo } });
  }

  error(message: string): ToastHandle {
    return this.show({ message, tone: 'error' });
  }

  async runAction(id: number): Promise<void> {
    const toast = this.toasts().find((item) => item.id === id);
    this.dismiss(id);
    await toast?.action?.handler();
  }

  dismiss(id: number): void {
    const timer = this.timers.get(id);
    if (timer) {
      clearTimeout(timer);
      this.timers.delete(id);
    }
    this.toasts.update((toasts) => toasts.filter((toast) => toast.id !== id));
  }

  private clearTimers(): void {
    this.timers.forEach((timer) => clearTimeout(timer));
    this.timers.clear();
  }
}
