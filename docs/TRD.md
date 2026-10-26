# TRD · Personal App (shell modular + módulo Finanzas)

| | |
|---|---|
| Estado | Borrador v0.2 |
| Fecha | 2026-10-26 |
| Basado en | [PRD.md](./PRD.md) |

---

## 1. Resumen de decisiones

| Área | Decisión |
|---|---|
| Repositorio | Monorepo: `app/` (Flutter) + `backend/` (Laravel) + `infra/` + `docs/` |
| Cliente | App nativa iOS en Flutter 3.47 / Dart 3.13 (bundle `dev.jotade.personal`, solo iOS). Riverpod 3, go_router 18, dio |
| UI | Librería propia "Ember" en `app/lib/ui` (widgets `Carli*`) sobre `ThemeExtension` de tokens. Iconos Hugeicons, gráficos fl_chart |
| Backend | Laravel 13, PHP 8.4, arquitectura modular por dominio (`app/Modules/*`) |
| BD | PostgreSQL 18, un esquema por módulo (`finance.*`), PK UUIDv7 |
| Auth | Laravel Sanctum: token personal (Bearer) en la app iOS, guardado en el Keychain. Laravel Fortify headless para 2FA TOTP. Bloqueo local con Face ID |
| Avisos | Notificación local diaria (20:00) con el número de pendientes y bandeja in-app. Sin push remoto hasta tener APNs |
| Colas y cron | Queue driver `database` + `schedule:work` en contenedor propio (sin Redis en v1) |
| Contrato API | REST JSON `/api/v1`, OpenAPI generado con Scramble. Modelos Dart escritos a mano en cada módulo (`data/`) |
| Despliegue | Backend: Docker Compose en VPS propio: Caddy (TLS + proxy de las rutas del backend) · PHP-FPM · worker · scheduler · Postgres. App: build de Xcode instalada en el dispositivo |
| Calidad | Pest + Larastan + Pint · `flutter analyze` + `flutter test` + `integration_test` · GitHub Actions |
| Open Banking (F3) | Enable Banking (AIS, modo restricted, gratis para cuentas propias) detrás de la interfaz `BankDataProvider`. Solo lectura |

> Versiones a fecha de octubre 2026. Fijarlas en `composer.json` / `pubspec.yaml` y actualizar con Renovate o Dependabot.

## 2. Arquitectura

```
┌──────────────── VPS (Docker Compose) ─────────────────────┐
│                                                           │
│  Caddy :443 ──┬── /api, /sanctum, /up… → php-fpm (Laravel)│
│               └── resto → 404                             │
│                                                           │
│  worker   (php artisan queue:work)                        │
│  scheduler(php artisan schedule:work)                     │
│  postgres (volumen persistente) ── backup diario ────────────► almacenamiento externo (restic)
└───────────────────────────────────────────────────────────┘
        ▲
        │ HTTPS + Bearer token
   App iOS (Flutter)
   └ notificación local 20:00
```

La app habla con `/api/v1` con un token personal de Sanctum (`Authorization: Bearer`), así que no depende de cookies ni de CORS. Caddy solo expone las rutas del backend (§10).

## 3. Estructura del monorepo

```
personal-app/
├── app/                     # Flutter (iOS)
├── backend/                 # Laravel 13
├── infra/
│   ├── docker/              # Dockerfiles (php, caddy, backup); la imagen de caddy se construye desde infra/
│   ├── scripts/
│   └── Caddyfile
├── compose.yaml
├── Makefile
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

**Sincronización bancaria (F3)** dentro de `Finance/BankSync/`:
- `Contracts/BankDataProvider`: `listAspsps()`, `startAuth(aspsp, redirectUrl)`, `completeAuth(code)`, `listAccounts(session)`, `fetchTransactions(accountUid, from, to)`, `fetchBalance(accountUid)`, `revoke(session)`.
- `Providers/EnableBankingProvider`: JWT RS256 firmado con la clave privada de la aplicación (TTL ≤ 24 h), cliente HTTP con reintentos y backoff.
- `Services/BankSyncService`: mapea al modelo propio y hace upsert idempotente. Aplica las reglas de autocategorización (PRD FI-BK-10); lo que no casa entra sin categoría. No toca periodos.

### 4.1.1 Pendientes (contrato de Core)

`Core/Pending/PendingItemsProvider` es la interfaz que implementa cada módulo para aportar elementos a Pendientes (PRD SH-12):

```php
interface PendingItemsProvider {
    public function moduleId(): string;                       // 'finance'
    public function count(User $user): int;                   // para el contador
    public function items(User $user, ?string $type, ?string $cursor): PendingPage;
}
// PendingItem: { module, type, id, title, subtitle, amount_cents?, date, route }
// tipos de Finanzas: 'uncategorized_transaction', 'recurring_to_confirm'
```

- Los módulos registran su provider en su ServiceProvider (`PendingRegistry::register(...)`); Core no conoce a los módulos, igual que con `ModuleRegistry`.
- **Pendiente es un estado calculado, no se guarda** (ADR-009). Finanzas: `category_id IS NULL AND kind IN ('expense','income') AND deleted_at IS NULL` (índice parcial de §5.3) y recurrentes con `status = 'pending'`. Un elemento sale de Pendientes en cuanto se resuelve, sin sincronizar nada.
- No se reutiliza `transactions.status = 'pending'` para "sin categoría": ese estado ya significa "recurrente sin confirmar" y afecta al saldo.
- Validación: `StoreTransactionRequest` exige `category_id` para `expense`/`income` salvo `source = 'bank'`.

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
- Value object `Money` en PHP (o `brick/money` si se prefiere librería). En la app se formatea en `core/format/money.dart` (`formatMoney`, `formatMoneyFigure`) sin depender del locale: separador de miles siempre (`2.695,00 €`, también con 4 dígitos), coma decimal, espacio duro antes de `€` y signo menos tipográfico (`−`).
- En la API se envían céntimos como entero (`"amount_cents": -1299`) para evitar ambigüedad; el cliente convierte.

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
| `sessions` | driver de sesión `database` (resto del cliente web, §6.3) |
| `personal_access_tokens` | tokens de Sanctum de la app iOS (uno por dispositivo, `name = 'carli iOS'`) |
| `user_modules` | user_id, module_id, enabled, settings jsonb |
| `push_subscriptions` | (del paquete webpush) endpoint, public_key, auth_token, user_agent. Resto del cliente web, §6.3 |
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

-- F3 · Sincronización bancaria
bank_connections (
  id uuid PK, user_id uuid FK,
  provider text DEFAULT 'enable_banking',
  aspsp_name text, aspsp_country char(2),      -- 'BBVA','ES' / 'MyInvestor','ES' / 'Revolut','LT'
  session_id text,                              -- cast encrypted en Laravel
  valid_until timestamptz NOT NULL,
  status text CHECK (status IN ('active','expired','revoked','error')),
  last_synced_at timestamptz NULL, last_error text NULL,
  timestamps
)

-- accounts añade:
--   bank_connection_id uuid NULL FK bank_connections,
--   external_account_uid text NULL,               -- uid de la cuenta en el proveedor
--   sync_from_date date NULL,                     -- PRD FI-BK-02
--   bank_balance_cents bigint NULL, bank_balance_at timestamptz NULL   -- PRD FI-BK-07

-- transactions añade:
--   source text CHECK (source IN ('manual','recurring','bank')) DEFAULT 'manual',
--   external_id text NULL,                        -- entry_reference / transaction_id del banco
--   raw jsonb NULL,                               -- payload original, para depurar
--   UNIQUE (account_id, external_id)              -- idempotencia entre sincronizaciones
--   índice parcial para la bandeja: WHERE category_id IS NULL AND kind IN ('expense','income')
```

Reglas de importación (F3):
- Los importados entran con `category_id NULL`.
- Borrado de importados con `deleted_at`. El upsert ignora `external_id` ya existentes **incluidos los borrados**, así no reaparecen (PRD FI-BK-06).
- Si el banco no da un id estable: `external_id = sha256(fecha|importe|concepto|n.º de ocurrencia ese día)`.
- Signo según `credit_debit_indicator` (DBIT → negativo). Solo `status = BOOK`.

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

Prefijo `/api/v1`. JSON. Autenticación con token Bearer de Sanctum. Errores con formato Laravel (`message`, `errors`). Paginación por cursor en listados largos.

### 6.1 Core

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/v1/auth/token` | App: `{ email, password, device_name, code? \| recovery_code? }` → `{ token, user }` o `{ two_factor: true }`. Mismo rate limit que el login |
| DELETE | `/api/v1/auth/token` | App: revoca solo el token en uso |
| GET/PATCH | `/api/v1/me` | Usuario + preferencias; perfil |
| PATCH | `/api/v1/me/preferences` | Tema, ajustes |
| PUT | `/api/v1/me/password` | Cambio de contraseña con la actual |
| POST/DELETE | `/api/v1/me/two-factor` | Activar (devuelve secreto y QR) / desactivar 2FA |
| POST | `/api/v1/me/two-factor/confirm` | Confirma la activación con un código TOTP |
| POST | `/api/v1/me/two-factor/recovery-codes[/regenerate]` | Ver / regenerar códigos de recuperación |
| GET | `/api/v1/me/tokens` | Dispositivos con token activo |
| DELETE | `/api/v1/me/tokens/{id}` | Revoca un dispositivo |
| POST | `/api/v1/me/tokens/logout-others` | Revoca todos menos el actual |
| GET | `/api/v1/modules` | Módulos habilitados |
| PATCH | `/api/v1/modules/{id}` | Activar/desactivar, settings |
| GET | `/api/v1/notifications` | Bandeja (paginada) |
| GET | `/api/v1/notifications/unread-count` | Contador del punto de no leídas |
| POST | `/api/v1/notifications/read` | Marcar leídas |
| GET/PUT | `/api/v1/notification-preferences` | Preferencias |
| GET | `/api/v1/pending/summary` | `{ total, by_module: [{ module, type, count }] }` para contador y tarjeta de Inicio |
| GET | `/api/v1/pending?module=&type=&cursor=` | Lista paginada de `PendingItem` |
| GET | `/api/v1/search?q=` | Búsqueda global (≥ 2 caracteres) |

Los endpoints `me/password`, `me/two-factor*` y `me/tokens*` sustituyen a las rutas de Fortify, que dependen de la sesión web; piden la contraseña actual en las operaciones sensibles y van limitados a 10/min.

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
| GET | `/bank/aspsps?country=ES` | Bancos disponibles (F3) |
| POST | `/bank/connections` | `{ aspsp_name, aspsp_country, return_to: 'app' }` → `{ auth_url }` |
| GET | `/bank/callback` | Vuelta del banco: valida `state`, crea sesión y redirige a vincular cuentas: a `carli://bank/callback` si el `state` cifrado lleva `return_to: app` |
| GET | `/bank/connections` | Estado, `valid_until`, último sync |
| POST | `/bank/connections/{id}/accounts` | `[{ external_account_uid, account_id \| new, sync_from_date }]` |
| POST | `/bank/connections/{id}/sync` | Sincronizar ahora (job en cola) |
| POST | `/bank/connections/{id}/renew` | Nuevo `auth_url` conservando las vinculaciones; también con `return_to: 'app'` |
| DELETE | `/bank/connections/{id}` | Revoca y marca `revoked` |

En F3, `GET /transactions` añade los filtros `source` y `uncategorized=1`.

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

### 6.3 Restos del cliente web

El backend todavía conserva piezas del cliente Angular, retirado el 2026-10-26. Ningún cliente las usa; se pueden quitar cuando convenga:

- Sesión de Sanctum por cookie: `statefulApi()` en `bootstrap/app.php`, `SANCTUM_STATEFUL_DOMAINS`, `SESSION_*`, `/sanctum/csrf-cookie` y la tabla `sessions`.
- Rutas web de Fortify: `POST /login`, `/logout`, `/two-factor-challenge`, `/forgot-password`, `/reset-password` y `/user/*` (Caddy aún las pasa al backend).
- `GET/DELETE /api/v1/me/sessions[/{id}]` y `POST /me/sessions/logout-others` (sesiones de navegador).
- Web Push: claves `VAPID_*` (`make setup` aún las genera), `GET /push/public-key`, `POST/DELETE /push-subscriptions`, la tabla `push_subscriptions` y el canal WebPush. Hoy el push de servidor no llega a ningún dispositivo hasta que exista APNs.
- El callback del banco redirige a la web cuando falta `return_to`.
- La preferencia `sidebar_collapsed` en `PATCH /me/preferences`.
- Las URLs de las notificaciones guardadas se generan con el formato de rutas de la web; la app las traduce a sus rutas en `core/notifications/notification_route.dart`.

## 7. App iOS (Flutter)

Cliente principal: app nativa en `app/` (Flutter 3.47, Dart 3.13), solo iOS (bundle `dev.jotade.personal`, iOS 15+). Sustituye a la PWA Angular, retirada del repo el 2026-10-26.

### 7.1 Estructura

```
app/lib/
├── main.dart, app.dart
├── core/
│   ├── api/              # dio + AuthInterceptor (Bearer, 401 → cerrar sesión), ApiConfig (API_URL), errores
│   ├── auth/             # AuthController, AuthRepository (token), TokenStore (Keychain), BiometricLock (Face ID)
│   ├── router/           # go_router: rutas, redirección por sesión, StatefulShellRoute
│   ├── theme/            # tokens.dart (CarliColors, CarliSpace, CarliRadius, CarliMotion), typography.dart, theme.dart, preferencia de tema
│   ├── format/           # dinero y fechas es-ES
│   ├── modules/          # AppModule + GET /modules
│   ├── pending/          # resumen y lista de Pendientes
│   ├── notifications/    # bandeja, contador de no leídas, ruta de cada aviso
│   ├── reminders/        # aviso local diario
│   ├── search/           # búsqueda global
│   ├── lifecycle/        # refresco de pendientes y no leídas al volver a primer plano
│   └── files/            # compartir ficheros (share_plus)
├── ui/                   # DESIGN SYSTEM "Ember": widgets Carli* (ver DESIGN-SYSTEM.md §3)
├── shell/                # launch, login, lock, home (Inicio), more (Más), pending, notifications, search, settings
├── modules/
│   └── finance/
│       ├── data/         # FinanceApi, modelos, providers, repositorios, Enable Banking
│       ├── screens/      # resumen, movimientos, presupuestos, cuentas, categorías, recurrentes, objetivos, deudas, compartidos, ajustes, bancos
│       └── ui/           # widgets propios del módulo (transaction-row, budget-line, period-selector, tarjeta de Inicio…)
└── dev/                  # catálogo de componentes (solo debug, /dev/catalogo)
```

Reglas: `modules/*` no se importan entre sí; `ui/` no importa de `modules/` ni de `shell/`. El cableado de cada módulo con el shell vive en puntos concretos: `core/router`, `core/pending` y las pantallas de Inicio, Pendientes y búsqueda.

### 7.2 Stack

| Paquete | Uso |
|---|---|
| `flutter_riverpod` 3 | Estado y dependencias (`Provider`, `Notifier`, `FutureProvider`); los providers de Finanzas se recargan por ámbito tras cada mutación |
| `go_router` 18 | Rutas y redirección según `AuthState` |
| `dio` | Cliente HTTP con `Authorization: Bearer <token>` |
| `flutter_secure_storage` | Token y preferencia de Face ID en el Keychain |
| `local_auth` | Bloqueo con Face ID (o Touch ID) al ocultar y volver a la app |
| `shared_preferences` | Preferencia de tema local (se sincroniza con `PATCH /me/preferences`) |
| `hugeicons` | Iconos (stroke rounded) |
| `fl_chart` | Gráficos dentro de `CarliChart` |
| `share_plus`, `path_provider` | Exportar CSV y compartir códigos de recuperación |
| `flutter_web_auth_2` | Consentimiento de Enable Banking en `ASWebAuthenticationSession` |
| `flutter_local_notifications`, `timezone`, `flutter_timezone` | Aviso local diario |
| `qr_flutter` | QR del alta de 2FA |
| `intl`, `flutter_localizations` | Locale `es-ES` |

### 7.3 Contrato de módulo en la app

```dart
class AppModule {            // core/modules/app_module.dart, se construye desde GET /modules
  final String id;           // 'finance'
  final String name, icon, route;
  final bool available, enabled;
  final Map<String, dynamic> settings;
}
```

Cada módulo aporta sus rutas en `core/router/router.dart`, su tarjeta de Inicio (`finance/ui/finance_home_card.dart`), sus acciones en línea para Pendientes (`shell/pending/finance_pending_actions.dart`) y su pantalla de ajustes (`moduleSettingsLocations`). El shell cruza esto con `GET /modules` para mostrar solo los habilitados.

### 7.4 Patrones

- Sesión: `POST /api/v1/auth/token` con `device_name = 'carli iOS'` (y código 2FA o de recuperación si hace falta) devuelve un token de Sanctum que se guarda en el Keychain. Un 401 con token borra la sesión y el router lleva a `/login`. Cerrar sesión llama a `DELETE /auth/token`.
- Face ID: si está activado, la app se bloquea al pasar a segundo plano y pide Face ID al volver; la animación de arranque espera al desbloqueo.
- Al volver a primer plano se refrescan el resumen de Pendientes y el contador de no leídas (`core/lifecycle/session_refresh.dart`).
- Aviso diario: notificación local a las 20:00 (hora local, configurable en Ajustes → Avisos) con el número de pendientes, reprogramada cada vez que la app vuelve a primer plano. Tocarla abre Pendientes. No hay APNs: el push remoto exige una cuenta de desarrollador de pago.
- Enable Banking: `POST /bank/connections` (o `/renew`) con `return_to: app` → `FlutterWebAuth2.authenticate(url, callbackUrlScheme: 'carli')`. El backend cierra el flujo redirigiendo a `carli://bank/callback` y la app abre la pantalla de vinculación.
- Dinero en céntimos (`int`) en toda la app; `CarliMoneyInput` devuelve céntimos.
- Formularios y altas en sheets (`showCarliSheet`, `showFullSheet`); confirmaciones con `CupertinoAlertDialog`; borrado con "Deshacer" en toast.
- Modelos y parseo JSON escritos a mano en `modules/*/data` (sin generación de código).

### 7.5 Rutas

Shell con `StatefulShellRoute.indexedStack` y 5 pestañas; cada una conserva su pila.

```
/arranque, /login
/                               Inicio            (+ /pendientes?modulo=&tipo=, /notificaciones, /buscar)
/finanzas                       Resumen
/finanzas/movimientos           Movimientos
/finanzas/presupuestos          Presupuestos
/mas                            Más
/mas/cuentas[/:id]
/mas/categorias, /mas/recurrentes, /mas/objetivos[/:id], /mas/deudas, /mas/compartidos[/:id]
/mas/ajustes-finanzas[/bancos[/:id/vincular?renovado=1]]
/mas/ajustes[/perfil|/seguridad|/avisos|/modulos|/apariencia]
/dev/catalogo                   solo en debug
```

El botón "+" flotante abre la hoja de nuevo movimiento desde cualquier pestaña. La pestaña Más muestra el contador de Pendientes.

## 8. Procesos en segundo plano

| Tarea | Frecuencia | Qué hace |
|---|---|---|
| `finance:materialize-recurring` | Diario 06:00 | Crea movimientos de reglas con `next_occurrence <= hoy` (confirmados si `auto`, pendientes si `confirm`) y avanza `next_occurrence`. Idempotente (clave única regla + fecha). |
| `finance:upcoming-charges` | Diario 09:00 | Push de cargos en `remind_days_before` días |
| Listener `TransactionSaved` | Evento | Recalcula consumo del presupuesto y notifica al cruzar 80/100 % (guardar umbral notificado por mes para no repetir) |
| Listener `PayrollRegistered` | Evento | Si el ingreso es de una categoría `opens_period`, está confirmado y han pasado ≥ N días desde el inicio del periodo abierto: cierra el actual (`end_date = fecha − 1`), abre uno nuevo y copia presupuestos, todo en una transacción. Al editar o borrar esa nómina, `PeriodService::rebuild()` recalcula límites. |
| `finance:payroll-overdue` | Diario 09:00 | Si hoy > `expected_end_date` + 1 y no hay periodo nuevo: push de aviso (PRD FI-PE-07) |
| `finance:weekly-summary` | Lunes 09:00 | Opcional |
| `finance:bank-sync` (F3) | 07:00, 13:00, 19:00 | Encola un job por conexión activa: trae movimientos desde `max(sync_from_date, último booking_date − 5 días)`, upsert por `external_id`, actualiza el saldo del banco. Respeta el límite PSD2 de 4 consultas/día sin usuario presente. Las alertas de presupuesto se evalúan una vez al final del job, no por movimiento. |
| `core:pending-digest` | Diario 20:00 | Si `PendingRegistry` suma > 0, un push con el resumen ("Tienes 7 movimientos por categorizar"); respeta las preferencias de notificación. Nunca por elemento ni por sincronización. Hoy no llega a ningún dispositivo (sin APNs); lo cubre el aviso local de §7.4 |
| `finance:bank-consent-expiry` (F3) | Diario 09:00 | Push a 7 y 1 día de `valid_until`; marca `expired` al pasar |
| `backup:database` | Diario 03:00 | `pg_dump` → restic → almacenamiento externo; retención 7 diarios / 4 semanales / 12 mensuales |

Mientras no haya APNs, los avisos de servidor solo se ven en la bandeja de notificaciones de la app.

Zona horaria de la app: `Europe/Madrid`; fechas de movimientos como `date` (sin hora).

## 9. Seguridad

- Sin registro: `php artisan app:create-user`.
- Fortify con rate limit de login (5/min) y 2FA TOTP; `POST /auth/token` usa el mismo limitador.
- App iOS: token de Sanctum por dispositivo en el Keychain (`flutter_secure_storage`), revocable desde Ajustes → Seguridad (`/me/tokens`). Bloqueo opcional con Face ID. Contraseña, 2FA y cierre de otros dispositivos piden la contraseña actual.
- Policies por modelo (aunque haya un usuario: protege contra IDs ajenos si un día hay más).
- Cabeceras en Caddy: HSTS, CSP `default-src 'none'` en la API (más permisiva solo en `/docs`), `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options`. Las rutas que no son del backend responden 404.
- Postgres sin puerto expuesto fuera de la red Docker. SSH con clave, firewall (solo 22/80/443), actualizaciones automáticas de seguridad del SO.
- Backups cifrados (restic) y **prueba de restauración** trimestral.
- Open Banking (F3): clave privada de Enable Banking como **Docker secret** en `/run/secrets/enable_banking.pem`, nunca en el repo ni en la BD; `ENABLE_BANKING_APP_ID` en `.env`. `bank_connections.session_id` cifrado (cast `encrypted`). La redirect URL registrada en Enable Banking es `https://<dominio>/api/v1/finance/bank/callback`; el destino final (`carli://bank/callback`) va en el `state` cifrado, de un solo uso y 30 min de validez. `transactions.raw` puede contener IBAN y nombres de contrapartes: queda cubierto por los backups cifrados.

## 10. Despliegue

`compose.yaml` (producción):

| Servicio | Imagen | Notas |
|---|---|---|
| `caddy` | caddy:2, build desde `infra/` (`infra/docker/caddy/Dockerfile`) | TLS automático. Solo pasa a `app:9000` (php_fastcgi) `/api`, `/sanctum/*`, `/user/*`, `/docs`, `/up`, `/broadcasting/*` y los POST de Fortify (`/login`, `/logout`, `/two-factor-challenge`…); cualquier otra ruta responde 404 |
| `app` | build propio (php:8.4-fpm + extensiones pgsql, intl, bcmath, gmp) | |
| `worker` | misma imagen | `php artisan queue:work --tries=3` |
| `scheduler` | misma imagen | `php artisan schedule:work` |
| `postgres` | postgres:18 | volumen `pgdata` |

Pipeline (GitHub Actions): tests → build imagen → push a GHCR → SSH al VPS → `docker compose pull && docker compose up -d && docker compose exec app php artisan migrate --force && php artisan optimize`.

Alternativa más simple a valorar: FrankenPHP (Caddy + PHP en una imagen) reduce un contenedor.

App iOS: se compila con Flutter/Xcode y se instala en el dispositivo; `API_URL` (`--dart-define`) fija el backend en tiempo de compilación (por defecto `http://MacBook-Pro-van-Yurest.local:8180/api`, red local). `NSLocalNetworkUsageDescription` y `NSFaceIDUsageDescription` están en `Info.plist`.

Desarrollo local: `make up` levanta el stack en `localhost:8180`; `flutter run -d <simulador> --dart-define=API_URL=http://127.0.0.1:8180/api` para la app.

## 11. Calidad y testing

| Capa | Herramienta | Cobertura mínima esperada |
|---|---|---|
| Backend unit/feature | Pest + `RefreshDatabase` sobre Postgres real (no SQLite: se usan esquemas y pg_trgm) | Servicios de dominio (saldos, transferencias, recurrentes, presupuestos) al 90 %; todos los endpoints con un test feature |
| Backend estático | Larastan nivel 8+, Pint | CI falla si hay errores |
| App estático | `flutter analyze` (`flutter_lints`); `make test-app` lanza este y `flutter test` | Sin avisos |
| App unit/widget | `flutter test`, con el adaptador `FakeApi` de `test/support` en lugar del `HttpClientAdapter` de dio | Formatos, providers, componentes de `ui/`, pantallas del shell y de Finanzas |
| App integración | `integration_test/` en simulador contra un backend local real (puerto 8181, base de pruebas sembrada con `SEED_DEMO_USER=true php artisan migrate:fresh --seed`): `flutter test integration_test/<fichero> -d <simulador> --dart-define=API_URL=http://127.0.0.1:8181/api` | Login y flujos de Core |
| Capturas | `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screenshots*_test.dart` con `SCREENSHOT_DIR` (y `SHOT_THEME`, `SHOT_PREFIX`) | Revisión visual en claro y oscuro |
| Accesibilidad | `Semantics` en widgets de `ui/`, tamaños táctiles ≥ 44 pt, revisión con VoiceOver | Etiquetas en todos los controles icon-only, gráficos con vista tabla |

## 12. Plan de implementación sugerido

1. **Infra base**: monorepo, compose dev, Laravel vacío, CI.
2. **Core backend**: auth Sanctum/Fortify, usuarios, módulos, notificaciones DB.
3. **Design system** (`ui/`): tokens, tema, componentes base; catálogo en `/dev/catalogo` (solo debug).
4. **Shell de la app**: login, bloqueo, pestañas, Inicio, ajustes, tema.
5. **Finanzas MVP**: cuentas → categorías (seeder) → movimientos y transferencias → dashboard → presupuestos.
6. **Avisos**: bandeja de notificaciones, Pendientes y aviso local diario; push remoto (APNs) cuando haya cuenta de desarrollador de pago.
7. **Producción**: VPS, Caddy, backups. Empezar a usarla.
8. **F2**: recurrentes → objetivos → compartidos → deudas → exportación.
9. **F3**: crear app en Enable Banking y enlazar Revolut, BBVA y MyInvestor en su panel (verificar que Revolut y MyInvestor aparecen, si salen las tarjetas BBVA y el `maximum_consent_validity` de cada banco) → `BankDataProvider` + modelo → conexión y vinculación → job de sync → bandeja "Sin categorizar" → avisos de caducidad.

## 13. ADRs a registrar

- ADR-001 Monorepo sin herramienta de orquestación (`app/`, `backend/`, `infra/` independientes).
- ADR-002 Importes en céntimos `bigint` con signo.
- ADR-003 Saldo calculado al vuelo.
- ADR-004 Un esquema Postgres por módulo.
- ADR-005 Cola en base de datos, sin Redis.
- ADR-006 Mismo origen SPA + API. Superado por ADR-010: la app usa token.
- ADR-007 Periodo financiero de nómina a nómina, calculado por rangos de fecha (sin `period_id` en movimientos).
- ADR-008 Open Banking vía agregador con licencia (Enable Banking, modo restricted) detrás de `BankDataProvider`. Descartados: acceso directo PSD2 (requiere licencia AISP + eIDAS), GoCardless Bank Account Data (sin altas nuevas en 2026) y Tink/Yapily/Salt Edge (de pago, contratación con ventas).
- ADR-009 Pendientes como estado calculado y contrato de Core (`PendingItemsProvider`), sin tabla propia ni flag en `transactions`.
- ADR-010 Cliente nativo iOS en Flutter en lugar de la PWA Angular, con token de Sanctum por dispositivo. El frontend Angular se retiró del repo el 2026-10-26.
- ADR-011 Aviso diario como notificación local mientras no haya APNs.
