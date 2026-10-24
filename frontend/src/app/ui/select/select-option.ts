export interface UiSelectOption<T = string> {
  value: T;
  label: string;
  icon?: string | null;
  description?: string | null;
  disabled?: boolean;
}

export const OVERLAY_BELOW_THEN_ABOVE = [
  { originX: 'start', originY: 'bottom', overlayX: 'start', overlayY: 'top', offsetY: 6 },
  { originX: 'start', originY: 'top', overlayX: 'start', overlayY: 'bottom', offsetY: -6 },
] as const;
