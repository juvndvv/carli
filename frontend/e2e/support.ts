import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { APIRequestContext, expect, Page } from '@playwright/test';

export const DEMO_EMAIL = process.env['E2E_EMAIL'] ?? 'demo@example.com';
export const DEMO_PASSWORD = process.env['E2E_PASSWORD'] ?? 'password';

const repositoryRoot = resolve(__dirname, '..', '..');

export function artisan(...args: string[]): string {
  return execFileSync('docker', ['compose', 'exec', '-T', 'app', 'php', 'artisan', ...args], {
    cwd: repositoryRoot,
    encoding: 'utf8',
  });
}

export async function login(page: Page, email = DEMO_EMAIL, password = DEMO_PASSWORD): Promise<void> {
  await page.goto('/login');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Contraseña').fill(password);
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page).not.toHaveURL(/\/login/);
}

export class FinanceApi {
  constructor(
    private readonly page: Page,
    private readonly request: APIRequestContext = page.request,
  ) {}

  async get<T>(path: string): Promise<T> {
    const response = await this.request.get(this.url(path), { headers: await this.headers() });
    expect(response.status(), `GET ${path}`).toBeLessThan(400);
    return (await response.json()) as T;
  }

  async send<T>(method: 'POST' | 'PUT' | 'PATCH' | 'DELETE', path: string, data?: unknown): Promise<T> {
    const response = await this.request.fetch(this.url(path), { method, data, headers: await this.headers() });
    expect(response.status(), `${method} ${path}: ${await response.text()}`).toBeLessThan(400);
    const text = await response.text();
    return (text ? JSON.parse(text) : {}) as T;
  }

  private url(path: string): string {
    return `/api/v1/${path.replace(/^\//, '')}`;
  }

  private async headers(): Promise<Record<string, string>> {
    const cookies = await this.page.context().cookies();
    const xsrf = cookies.find((cookie) => cookie.name === 'XSRF-TOKEN')?.value ?? '';
    const origin = new URL(this.page.url() === 'about:blank' ? 'http://localhost:8180' : this.page.url()).origin;
    return {
      Accept: 'application/json',
      'X-XSRF-TOKEN': decodeURIComponent(xsrf),
      'X-Requested-With': 'XMLHttpRequest',
      Referer: `${origin}/`,
    };
  }
}

export interface ApiList<T> {
  data: T[];
}

export interface ApiItem<T> {
  data: T;
}

export function uniqueLabel(prefix: string): string {
  return `${prefix} ${Date.now().toString(36)}`;
}

export function trackConsoleErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error' && !/status of 401/.test(message.text())) {
      errors.push(message.text());
    }
  });
  return errors;
}
