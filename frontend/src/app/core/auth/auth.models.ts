export type ThemePreference = 'system' | 'light' | 'dark';

export interface UserPreferences {
  theme?: ThemePreference;
  [key: string]: unknown;
}

export interface CurrentUser {
  id: string;
  name: string;
  email: string;
  two_factor_enabled: boolean;
  preferences: UserPreferences;
}

export interface Credentials {
  email: string;
  password: string;
  remember: boolean;
}

export type LoginResult = 'authenticated' | 'two_factor';

export type TwoFactorAnswer = { code: string } | { recovery_code: string };

export interface ActiveSession {
  id: string;
  device: string;
  browser: string | null;
  platform: string | null;
  is_mobile: boolean;
  ip_address: string | null;
  last_active_at: string;
  is_current: boolean;
}
