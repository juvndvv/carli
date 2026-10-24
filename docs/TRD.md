# TRD · Personal App (shell modular + módulo Finanzas)

| | |
|---|---|
| Estado | Borrador v0.1 |
| Fecha | 2026-10-24 |
| Basado en | [PRD.md](./PRD.md) |

---

## 1. Resumen de decisiones

| Área | Decisión |
|---|---|
| Repositorio | Monorepo: `frontend/` (Angular) + `backend/` (Laravel) + `infra/` + `docs/` |
| Frontend | Angular 22, standalone components, signals, zoneless, control flow nativo, lazy loading por módulo |
| UI | Design system propio sobre Tailwind CSS v4 + tokens CSS + Angular CDK (a11y, overlay, portal). Iconos Lucide |
| Backend | Laravel 13, PHP 8.4, arquitectura modular por dominio (`app/Modules/*`) |
| BD | PostgreSQL 18, un esquema por módulo (`finance.*`), PK UUIDv7 |
| Auth | Laravel Sanctum (SPA, cookie de sesión, mismo dominio) + Laravel Fortify headless para 2FA TOTP |
| Push | Web Push (VAPID) con `laravel-notification-channels/webpush` + `@angular/service-worker` (SwPush) |
| Colas y cron | Queue driver `database` + `schedule:work` en contenedor propio (sin Redis en v1) |
| Contrato API | REST JSON `/api/v1`, OpenAPI generado con Scramble, tipos TS generados con `openapi-typescript` |
| Despliegue | Docker Compose en VPS propio: Caddy (TLS + estáticos + proxy) · PHP-FPM · worker · scheduler · Postgres |
| Calidad | Pest + Larastan + Pint · Vitest + Playwright + ESLint · GitHub Actions |

> Versiones a fecha de octubre 2026. Fijarlas en `composer.json` / `package.json` y actualizar con Renovate o Dependabot.

## 2. Arquitectura

```
┌──────────────── VPS (Docker Compose) ────────────────┐
│                                                      │
│  Caddy :443 ──┬── /           → Angular build (PWA)  │
│               └── /api, /sanctum → php-fpm (Laravel) │
│                                                      │
│  worker   (php artisan queue:work)                   │
│  scheduler(php artisan schedule:work)                │
│  postgres (volumen persistente) ── backup diario ───────► almacenamiento externo (restic)
└──────────────────────────────────────────────────────┘
        ▲                                  │
        │ HTTPS (cookie de sesión)         │ Web Push (VAPID)
   Navegador / PWA  ◄── Push service (FCM / APNs / Mozilla) 
```

Mismo origen para SPA y API (`https://app.tudominio.com` y `https://app.tudominio.com/api`): elimina problemas de CORS y simplifica Sanctum (cookies `SameSite=Lax`).

## 3. Estructura del monorepo

```
personal-app/
├── backend/                 # Laravel 13
├── frontend/                # Angular 22
├── infra/
│   ├── docker/              # Dockerfiles (php, caddy)
│   ├── compose.yaml
│   ├── compose.dev.yaml
│   └── Caddyfile
├── docs/                    # PRD, TRD, DESIGN-SYSTEM, ADRs
├── mockup/
└── .github/workflows/
```

## 4. Backend (Laravel)

### 4.1 Arquitectura modular por dominio

```
backend/app/
├── Core/                         # Shell: auth, usuarios, módulos, notificaciones, push
│   ├── Http/Controllers/
│   ├── Models/User.php
│   ├── Modules/ModuleRegistry.php
│   └── Notifications/
└── Modules/
    └── Finance/
        ├── FinanceServiceProvider.php   # registra rutas, migraciones, schedule, políticas
        ├── module.php                   # manifiesto: id, nombre, icono, permisos, notificaciones
        ├── Domain/
        │   ├── Enums/ (AccountType, TransactionKind, RecurrenceFrequency…)
        │   ├── ValueObjects/Money.php
        │   └── Services/ (TransactionService, TransferService, BudgetService, RecurringService…)
        ├── Models/ (Account, Transaction, Category, Tag, Budget, RecurringRule, SavingsGoal, Debt, Contact…)
        ├── Http/
        │   ├── Controllers/
        │   ├── Requests/            # FormRequest por endpoint
        │   └── Resources/           # API Resources
        ├── Policies/
        ├── Events/ Listeners/       # TransactionSaved → CheckBudgetThreshold
        ├── Jobs/                    # MaterializeRecurringJob, SendUpcomingChargeReminders
        ├── Notifications/
        ├── Queries/                 # consultas de reporting (dashboard)
        ├── database/migrations/
        ├── database/seeders/        # categorías por defecto
        ├── routes/api.php
        └── tests/
```

Reglas:
- Un módulo **no importa** modelos de otro módulo. Si necesita algo, lo pide por un contrato en `Core` o por eventos.
- `Core` no conoce a los módulos: los descubre por `config/modules.php` (lista de service providers habilitados).
- Controladores finos: validación en FormRequest, lógica en `Domain/Services`, salida en Resources.
- Toda escritura que afecte a saldos (transferencias, splits, liquidaciones) dentro de `DB::transaction()`.

### 4.2 Registro de módulos

`GET /api/v1/modules` devuelve los módulos habilitados para el usuario:

```json
[{ "id": "finance", "name": "Finanzas", "icon": "wallet", "enabled": true, "route": "/finanzas" }]
```

Tabla `public.user_modules (user_id, module_id, enabled, settings jsonb)`.

Cada módulo expone además `GET /api/v1/{module}/summary` para la tarjeta del Inicio.

### 4.3 Dinero

- Importes como **enteros en céntimos** (`bigint`), nunca `float`. Columnas `*_cents`.
- Signo: `amount_cents` **negativo = sale dinero de la cuenta**, positivo = entra. Así `saldo = initial_balance_cents + SUM(amount_cents)`.
- Value object `Money` en PHP (o `brick/money` si se prefiere librería); en el frontend se formatea con `Intl.NumberFormat('es-ES', { style: 'currency', currency: 'EUR', useGrouping: 'always' })`. Ojo: sin `useGrouping: 'always'`, el locale es-ES no pone separador de miles en cifras de 4 dígitos (muestra `2695,00 €` en vez de `2.695,00 €`).
- En la API se envían céntimos como entero (`"amount_cents": -1299`) para evitar ambigüedad; el frontend convierte.

### 4.4 Saldos

MVP: el saldo se **calcula al vuelo** con `SUM` indexado (para un usuario son miles de filas, coste despreciable). Evita inconsistencias de un saldo cacheado. Si algún día hace falta, se añade una vista materializada o columna cacheada con recálculo por comando `finance:recalculate-balances`.

## 5. Modelo de datos (PostgreSQL)

### 5.1 Convenciones

- PK `uuid` (UUIDv7, ordenable por tiempo; Laravel `HasUuids`).
- Esquema `public` para framework y Core; esquema `finance` para el módulo. Migración inicial: `CREATE SCHEMA IF NOT EXISTS finance;` y los modelos con `protected $table = 'finance.accounts'`.
- Todas las tablas del módulo llevan `user_id` (FK a `public.users`) y se filtran por él vía global scope.
- `created_at`, `updated_at`; `deleted_at` (soft delete) solo donde se indica.
- Enums como `text` + `CHECK` (más fácil de migrar que tipos `ENUM` de Postgres) y Enums PHP respaldados.

### 5.2 Core (`public`)

| Tabla | Campos clave |
|---|---|
| `users` | id, name, email, password, two_factor_secret, two_factor_recovery_codes, preferences jsonb (tema, locale) |
| `sessions` | driver de sesión `database` |
| `user_modules` | user_id, module_id, enabled, settings jsonb |
| `push_subscriptions` | (del paquete webpush) endpoint, public_key, auth_token, user_agent |
| `notifications` | canal `database` de Laravel (bandeja de la app) |
| `notification_preferences` | user_id, module_id, type, push bool, in_app bool |
| `jobs`, `failed_jobs`, `cache` | framework |

### 5.3 Finanzas (`finance`)

```sql
accounts (
  id uuid PK, user_id uuid FK,
  name text, type text CHECK (type IN ('checking','savings','credit_card','cash')),
  initial_balance_cents bigint DEFAULT 0, initial_balance_date date,
  credit_limit_cents bigint NULL, statement_day smallint NULL, payment_day smallint NULL,
  color text, icon text, include_in_net_worth bool DEFAULT true,
  sort_order int, archived_at timestamptz NULL, timestamps
)

categories (
  id uuid PK, user_id uuid FK, parent_id uuid NULL FK categories,
  name text, kind text CHECK (kind IN ('expense','income')),
  icon text, color text, sort_order int, archived_at timestamptz NULL, timestamps,
  UNIQUE (user_id, parent_id, name)
)

transactions (
  id uuid PK, user_id uuid FK, account_id uuid FK,
  kind text CHECK (kind IN ('expense','income','transfer','adjustment')),
  amount_cents bigint NOT NULL,              -- con signo
  date date NOT NULL,
  category_id uuid NULL FK,                  -- NULL en transferencias / splits
  payee text NULL, description text NULL, notes text NULL,
  status text CHECK (status IN ('pending','cleared')) DEFAULT 'cleared',
  transfer_group_id uuid NULL,               -- une las 2 patas de una transferencia
  recurring_rule_id uuid NULL FK,
  debt_id uuid NULL FK,
  deleted_at timestamptz NULL, timestamps
)
-- índices: (user_id, date DESC), (account_id, date), (category_id, date), (transfer_group_id)
-- búsqueda: GIN pg_trgm sobre (payee || ' ' || description)

transaction_splits (id, transaction_id FK, category_id FK, amount_cents)   -- Could
tags (id, user_id, name, color, UNIQUE(user_id, name))
transaction_tag (transaction_id, tag_id, PK compuesta)

periods (
  id, user_id,
  start_date date NOT NULL,
  end_date date NULL,                        -- NULL = periodo abierto (el actual)
  expected_end_date date NULL,               -- según próxima nómina prevista (PRD FI-PE-06)
  opened_by text CHECK (opened_by IN ('payroll','manual','calendar')),
  opening_transaction_id uuid NULL FK transactions,
  timestamps,
  UNIQUE (user_id, start_date),
  EXCLUDE USING gist (user_id WITH =, daterange(start_date, end_date, '[]') WITH &&)  -- sin solapes (btree_gist)
)
-- categories añade: opens_period bool DEFAULT false

budgets (
  id, user_id, category_id FK, period_id FK periods,
  amount_cents bigint, rollover bool DEFAULT false, timestamps,
  UNIQUE (user_id, category_id, period_id)
)

recurring_rules (
  id, user_id, account_id, category_id, kind, amount_cents, payee, description,
  frequency text CHECK (frequency IN ('daily','weekly','monthly','yearly')),
  interval smallint DEFAULT 1, day_of_month smallint NULL,
  start_date date, end_date date NULL, next_occurrence date,
  mode text CHECK (mode IN ('auto','confirm')),
  remind_days_before smallint DEFAULT 2,
  is_subscription bool DEFAULT false, cancelled_at timestamptz NULL, timestamps
)

savings_goals (id, user_id, name, target_cents, target_date NULL, account_id NULL FK, icon, color, achieved_at NULL, timestamps)
goal_contributions (id, goal_id FK, amount_cents, date, transaction_id NULL FK)

contacts (id, user_id, name, notes, archived_at NULL, timestamps)

shared_expense_shares (
  id, transaction_id FK, contact_id FK, amount_cents bigint,  -- parte que corresponde al contacto (positivo)
  settled_at timestamptz NULL, settlement_transaction_id uuid NULL FK
)

debts (
  id, user_id, contact_id NULL FK, name text,
  direction text CHECK (direction IN ('i_owe','owed_to_me')),
  principal_cents bigint, start_date date, due_date date NULL,
  installment_cents bigint NULL, installments_count int NULL, recurring_rule_id NULL FK,
  closed_at NULL, timestamps
)
-- pagos de deuda = transactions con debt_id
```

### 5.4 Reglas de cálculo

| Concepto | Cálculo |
|---|---|
| Saldo de cuenta | `initial_balance_cents + SUM(amount_cents)` de movimientos no borrados (pendientes incluidos, mostrados aparte) |
| Patrimonio neto | Suma de saldos de cuentas con `include_in_net_worth` y no archivadas (tarjeta de crédito tiene saldo negativo) |
| Gasto propio por categoría | `SUM(-amount_cents)` de `kind='expense'` **menos** `shared_expense_shares.amount_cents`; transferencias excluidas; splits se reparten por `transaction_splits` |
| Presupuesto consumido | Gasto propio del periodo en la categoría y sus hijas (+ rollover del periodo previo si aplica) |
| Saldo con un contacto | `SUM(shares no liquidadas)` + deudas abiertas `owed_to_me` − deudas `i_owe` − pagos |
| Periodo financiero | `[start_date, end_date]`; el abierto llega hasta hoy. Un movimiento pertenece al periodo cuyo rango contiene su `date`. No se guarda `period_id` en `transactions`, así mover límites no obliga a reescribir movimientos |

## 6. API REST

Prefijo `/api/v1`. JSON. Autenticación por cookie de sesión Sanctum. Errores con formato Laravel (`message`, `errors`). Paginación por cursor en listados largos.

### 6.1 Core

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/sanctum/csrf-cookie` | Inicializa CSRF |
| POST | `/login`, `/logout` | Fortify |
| POST | `/two-factor-challenge` | Fortify |
| GET | `/api/v1/me` | Usuario + preferencias |
| PATCH | `/api/v1/me/preferences` | Tema, ajustes |
| GET | `/api/v1/modules` | Módulos habilitados |
| PATCH | `/api/v1/modules/{id}` | Activar/desactivar, settings |
| GET | `/api/v1/notifications` | Bandeja (paginada) |
| POST | `/api/v1/notifications/read` | Marcar leídas |
| POST/DELETE | `/api/v1/push-subscriptions` | Alta/baja de suscripción push |
| GET/PUT | `/api/v1/notification-preferences` | Preferencias |

### 6.2 Finanzas (`/api/v1/finance`)

| Método | Ruta | Notas |
|---|---|---|
| GET | `/summary` | Tarjeta del Inicio |
| GET | `/periods` | Lista de periodos (para el selector) |
| POST | `/periods` | Abrir periodo manual `{ start_date }` |
| PATCH | `/periods/{id}` | Mover `start_date` (recalcula el `end_date` del anterior) |
| GET | `/dashboard?period_id=` | KPIs, por categoría, últimos 12 periodos, presupuestos top, próximos cargos (por defecto el periodo abierto) |
| CRUD | `/accounts` | `GET` incluye `balance_cents` |
| POST | `/accounts/{id}/reconcile` | `{ actual_balance_cents }` → crea ajuste |
| CRUD | `/transactions` | Filtros: `from,to,account_id[],category_id[],tag[],kind,min,max,q,status`; cursor |
| POST | `/transfers` | `{ from_account_id, to_account_id, amount_cents, date }` crea 2 filas atómicas |
| PATCH | `/transactions/bulk` | Edición masiva |
| GET | `/transactions/export.csv` | Mismos filtros |
| GET | `/payees/suggest?q=` | Autocompletado + categoría sugerida |
| CRUD | `/categories`, `/tags` | `DELETE /categories/{id}?reassign_to=` |
| GET/PUT | `/budgets?period_id=` | Upsert masivo del periodo |
| POST | `/budgets/copy` | `{ from_period_id, to_period_id }` |
| CRUD | `/recurring-rules` | |
| POST | `/recurring-rules/{id}/confirm` | Confirma la ocurrencia pendiente (importe editable) |
| CRUD | `/goals`, `/goals/{id}/contributions` | |
| CRUD | `/contacts` | `GET` incluye saldo |
| POST | `/contacts/{id}/settle` | Liquida saldo, crea movimiento |
| CRUD | `/debts` | |

Ejemplo de movimiento:

```json
{
  "id": "0192f0c4-…",
  "account_id": "…",
  "kind": "expense",
  "amount_cents": -4250,
  "date": "2026-10-23",
  "category": { "id": "…", "name": "Supermercado", "parent": "Alimentación", "icon": "shopping-cart" },
  "payee": "Mercadona",
  "tags": ["casa"],
  "status": "cleared",
  "shares": [{ "contact_id": "…", "name": "Ana", "amount_cents": 2125, "settled": false }]
}
```

## 7. Frontend (Angular)

### 7.1 Estructura

```
frontend/src/app/
├── core/                 # auth (guards, interceptor CSRF), api client generado, module registry, push, theme
├── shell/                # layout, sidebar, bottom-nav, topbar, launcher (Inicio), ajustes globales, bandeja
├── ui/                   # DESIGN SYSTEM: button, input, money-input, select, dialog, sheet, toast, card,
│                         #   progress, badge, tabs, empty-state, skeleton, data-list, chart wrappers…
├── shared/               # pipes (money, relativeDate), utils
└── modules/
    └── finance/
        ├── finance.manifest.ts   # nav items, widget de Inicio, settings
        ├── finance.routes.ts     # lazy
        ├── data-access/          # servicios + stores con signals
        ├── features/             # dashboard, transactions, accounts, budgets, recurring, goals, debts, shared, settings
        └── ui/                   # componentes propios del módulo (transaction-row, category-picker…)
```

Alias de paths: `@core/*`, `@ui/*`, `@finance/*`. Regla de lint (`eslint-plugin-boundaries` o `@nx/enforce-module-boundaries` si se adopta Nx): `modules/*` no se importan entre sí; `ui` no importa de `modules`.

### 7.2 Contrato de módulo en el frontend

```ts
export interface AppModuleManifest {
  id: 'finance' | 'tasks' | 'health' | 'habits' | 'notes';
  name: string;
  icon: string;                       // nombre Lucide
  basePath: string;                   // '/finanzas'
  routes: () => Promise<Routes>;      // lazy
  nav: { label: string; path: string; icon: string }[];
  homeWidget?: () => Promise<Type<unknown>>;
  settings?: () => Promise<Type<unknown>>;
}
```

`provideAppModules([financeManifest])` en `app.config.ts`. El shell cruza la lista local con `GET /modules` para mostrar solo los habilitados.

### 7.3 Patrones

- Standalone + `ChangeDetectionStrategy.OnPush` + zoneless (`provideZonelessChangeDetection`).
- Estado: servicios con `signal`/`computed` por feature; lectura remota con `resource`/`httpResource` o `HttpClient` + signals. Sin NgRx (sobra para un usuario).
- Formularios: Reactive Forms tipados (valorar Signal Forms cuando estén estables).
- `LOCALE_ID = 'es-ES'`, `registerLocaleData(es)`, `MoneyPipe` sobre `Intl`.
- Gráficos: Chart.js con un wrapper propio en `ui/chart` que lee los tokens CSS (funciona en claro y oscuro).
- PWA: `@angular/service-worker` (`ng add @angular/pwa`), estrategia `freshness` para `/api` (sin offline real) y caché de assets.
- Push: `SwPush.requestSubscription({ serverPublicKey })` → `POST /push-subscriptions`. Click en notificación abre la URL del payload (`notificationclicks`).
- Interceptor HTTP: `withCredentials`, `X-XSRF-TOKEN`, 401 → `/login`, 419 → refrescar CSRF y reintentar una vez.
- Tipos: `openapi-typescript` contra el OpenAPI de Scramble (`npm run api:types`).

### 7.4 Rutas

```
/login
/                         Inicio (launcher)
/finanzas                 Dashboard
/finanzas/movimientos     (+ ?filtros en query params)
/finanzas/movimientos/nuevo  (sheet en móvil, diálogo en escritorio)
/finanzas/cuentas[/:id]
/finanzas/presupuestos?periodo=<id>
/finanzas/recurrentes
/finanzas/objetivos[/:id]
/finanzas/deudas
/finanzas/compartidos[/:contactId]
/finanzas/ajustes
/ajustes                  perfil, seguridad, tema, notificaciones, módulos
```

## 8. Procesos en segundo plano

| Tarea | Frecuencia | Qué hace |
|---|---|---|
| `finance:materialize-recurring` | Diario 06:00 | Crea movimientos de reglas con `next_occurrence <= hoy` (confirmados si `auto`, pendientes si `confirm`) y avanza `next_occurrence`. Idempotente (clave única regla + fecha). |
| `finance:upcoming-charges` | Diario 09:00 | Push de cargos en `remind_days_before` días |
| Listener `TransactionSaved` | Evento | Recalcula consumo del presupuesto y notifica al cruzar 80/100 % (guardar umbral notificado por mes para no repetir) |
| Listener `PayrollRegistered` | Evento | Si el ingreso es de una categoría `opens_period`, está confirmado y han pasado ≥ N días desde el inicio del periodo abierto: cierra el actual (`end_date = fecha − 1`), abre uno nuevo y copia presupuestos, todo en una transacción. Al editar o borrar esa nómina, `PeriodService::rebuild()` recalcula límites. |
| `finance:payroll-overdue` | Diario 09:00 | Si hoy > `expected_end_date` + 1 y no hay periodo nuevo: push de aviso (PRD FI-PE-07) |
| `finance:weekly-summary` | Lunes 09:00 | Opcional |
| `backup:database` | Diario 03:00 | `pg_dump` → restic → almacenamiento externo; retención 7 diarios / 4 semanales / 12 mensuales |

Zona horaria de la app: `Europe/Madrid`; fechas de movimientos como `date` (sin hora).

## 9. Seguridad

- Sin registro: `php artisan app:create-user`.
- Fortify con rate limit de login (5/min) y 2FA TOTP.
- Cookies `Secure`, `HttpOnly`, `SameSite=Lax`; `SESSION_DOMAIN` y `SANCTUM_STATEFUL_DOMAINS` al dominio de la app.
- Policies por modelo (aunque haya un usuario: protege contra IDs ajenos si un día hay más).
- Cabeceras en Caddy: HSTS, CSP estricta, `X-Content-Type-Options`, `Referrer-Policy`.
- Postgres sin puerto expuesto fuera de la red Docker. SSH con clave, firewall (solo 22/80/443), actualizaciones automáticas de seguridad del SO.
- Backups cifrados (restic) y **prueba de restauración** trimestral.

## 10. Despliegue

`infra/compose.yaml` (producción):

| Servicio | Imagen | Notas |
|---|---|---|
| `caddy` | caddy:2 | TLS automático, sirve `frontend/dist`, proxy `/api`, `/sanctum`, `/login`… a `app:9000` (php_fastcgi) |
| `app` | build propio (php:8.4-fpm + extensiones pgsql, intl, bcmath, gmp) | |
| `worker` | misma imagen | `php artisan queue:work --tries=3` |
| `scheduler` | misma imagen | `php artisan schedule:work` |
| `postgres` | postgres:18 | volumen `pgdata` |

Pipeline (GitHub Actions): tests → build imagen → push a GHCR → SSH al VPS → `docker compose pull && docker compose up -d && docker compose exec app php artisan migrate --force && php artisan optimize`.

Alternativa más simple a valorar: FrankenPHP (Caddy + PHP en una imagen) reduce un contenedor.

Desarrollo local: `compose.dev.yaml` con Postgres + Mailpit; `php artisan serve` y `ng serve` con proxy (`proxy.conf.json` → `/api` a `localhost:8000`) para mantener mismo origen.

## 11. Calidad y testing

| Capa | Herramienta | Cobertura mínima esperada |
|---|---|---|
| Backend unit/feature | Pest + `RefreshDatabase` sobre Postgres real (no SQLite: se usan esquemas y pg_trgm) | Servicios de dominio (saldos, transferencias, recurrentes, presupuestos) al 90 %; todos los endpoints con un test feature |
| Backend estático | Larastan nivel 8+, Pint | CI falla si hay errores |
| Frontend unit | Vitest (runner por defecto en Angular reciente) | Servicios, pipes, componentes de `ui/` |
| E2E | Playwright | 5 flujos del PRD §7.3 |
| Accesibilidad | `@axe-core/playwright` en e2e | 0 violaciones serias |

## 12. Plan de implementación sugerido

1. **Infra base**: monorepo, compose dev, Laravel + Angular vacíos, CI.
2. **Core backend**: auth Sanctum/Fortify, usuarios, módulos, notificaciones DB.
3. **Design system** (`ui/`): tokens, tema, componentes base; página `/dev/ui` de catálogo.
4. **Shell frontend**: login, layout, launcher, ajustes, tema.
5. **Finanzas MVP**: cuentas → categorías (seeder) → movimientos y transferencias → dashboard → presupuestos.
6. **PWA + push** (instalación, suscripción, aviso de presupuesto).
7. **Producción**: VPS, Caddy, backups. Empezar a usarla.
8. **F2**: recurrentes → objetivos → compartidos → deudas → exportación.

## 13. ADRs a registrar

- ADR-001 Monorepo sin Nx (o con Nx): decidir si compensa Nx solo para Angular.
- ADR-002 Importes en céntimos `bigint` con signo.
- ADR-003 Saldo calculado al vuelo.
- ADR-004 Un esquema Postgres por módulo.
- ADR-005 Cola en base de datos, sin Redis.
- ADR-006 Mismo origen SPA + API.
- ADR-007 Periodo financiero de nómina a nómina, calculado por rangos de fecha (sin `period_id` en movimientos).
