# TRD · Personal App (shell modular + módulos Finanzas, Tareas, Notas y Hábitos)

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
| BD | PostgreSQL 18, un esquema por módulo (`finance.*`, `tasks.*`, `notes.*`, `habits.*`), PK UUIDv7 |
| Auth | Laravel Sanctum: token personal (Bearer) en la app iOS, guardado en el Keychain. Laravel Fortify headless para 2FA TOTP. Bloqueo local con Face ID |
| Avisos | Push por APNs (resumen de pendientes a las 20:00 y avisos de cada módulo) y bandeja in-app |
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
- Nombre de cuenta: Enable Banking pone el titular en `name` y el nombre de la cuenta en `details` o `product`. `BankAccount::suggestedName()` propone «Banco · details|product» o, sin ellos, «Banco · Compartida» (titulares con « & »), «· Tarjeta», «· Ahorro» o «· Principal».
- `Providers/EnableBankingProvider`: JWT RS256 firmado con la clave privada de la aplicación (TTL ≤ 24 h), cliente HTTP con reintentos y backoff.
- `Services/BankSyncService`: mapea al modelo propio y hace upsert idempotente. Aplica las reglas de autocategorización (PRD FI-BK-10); lo que no casa entra sin categoría. Antes, `RecurringBankMatcher` busca un recurrente de la misma cuenta y tipo (previsto pendiente o `next_occurrence` a ±5 días; importe exacto, o comercio contenido con `MerchantText` y diferencia ≤ 50 %); si lo hay, el previsto pasa a `source = 'bank'` con importe y fecha del banco vía `TransactionService::update` (respeta periodos), o se crea el movimiento enlazado a esa ocurrencia y se avanza la regla (PRD FI-BK-16). Al final llama a `TransferDetector` (§4.1.2). No toca periodos.

### 4.1.1 Pendientes (contrato de Core)

`Core/Pending/PendingItemsProvider` es la interfaz que implementa cada módulo para aportar elementos a Pendientes (PRD SH-12):

```php
interface PendingItemsProvider {
    public function moduleId(): string;                       // 'finance'
    public function count(User $user): int;                   // para el contador
    public function items(User $user, ?string $type, ?string $cursor): PendingPage;
}
// PendingItem: { module, type, id, title, subtitle, amount_cents?, date, route }
// tipos de Finanzas: 'transfer_suggestion', 'uncategorized_transaction', 'recurring_to_confirm'
```

- Los módulos registran su provider en su ServiceProvider (`PendingRegistry::register(...)`); Core no conoce a los módulos, igual que con `ModuleRegistry`.
- **Pendiente es un estado calculado, no se guarda** (ADR-009). Finanzas: `category_id IS NULL AND kind IN ('expense','income') AND deleted_at IS NULL` (índice parcial de §5.3) y recurrentes con `status = 'pending'`. Un elemento sale de Pendientes en cuanto se resuelve, sin sincronizar nada.
- No se reutiliza `transactions.status = 'pending'` para "sin categoría": ese estado ya significa "recurrente sin confirmar" y afecta al saldo.
- `transfer_suggestion` también es calculado: son las parejas que devuelve `TransferDetector::candidates()` (§4.1.2). `id` = id del gasto; `meta` lleva `outgoing_transaction_id`, `incoming_transaction_id`, las dos cuentas, las fechas, `signals` y `unique`. `amount_cents` es el importe en positivo (la app lo pinta neutro). Los movimientos de una sugerencia se quitan de `uncategorized_transaction` para no pedir dos veces lo mismo; en Movimientos siguen marcados "Por revisar".
- Validación: `StoreTransactionRequest` exige `category_id` para `expense`/`income` salvo `source = 'bank'`.

### 4.1.2 Detección de transferencias entre cuentas propias (PRD FI-BK-12..14)

`Domain/Services/TransferDetector` + `TransferConversionService`. Solo mira movimientos `source = 'bank'`, no borrados, `cleared`, de tipo `expense`/`income`, sin `transfer_group_id`, deuda, recurrente, splits ni partes compartidas.

1. **Parejas** (una consulta SQL): gasto `o` y ingreso `i` del mismo usuario, `i.amount_cents = -o.amount_cents`, `o.account_id <> i.account_id`, `|i.date − o.date| ≤ 3` y sin fila en `transfer_exclusions` para `(o, i)`.
2. **Unicidad**: la pareja es única si `o` solo casa con `i` **y** `i` solo casa con `o`.
3. **Señales fuertes** (`signals`):
   - `iban`: el IBAN de la contraparte del raw (`creditor_account` del gasto / `debtor_account` del ingreso; claves `iban`, `bban` u `other.identification`) coincide con el IBAN de la otra cuenta. Solo se guarda el IBAN enmascarado de cada cuenta (`ES75 •••• 7919` en `bank_connections.accounts`), así que se comparan país + dígitos de control + últimos 4; si el banco también lo enmascara (`ES******7919`), país + últimos 4. No se guardan ni se exponen IBAN completos.
   - `holder`: el nombre de la contraparte (`creditor.name` del gasto / `debtor.name` del ingreso, o `payee`) es el titular. Titulares = `users.name` y el nombre del lado propio del raw de ambas patas (`debtor` del gasto, `creditor` del ingreso), porque el perfil puede no tener el nombre real. Comparación con `MerchantText::normalize` (sin acentos, mayúsculas, solo letras): el nombre con menos palabras (≥ 2) debe estar contenido en el otro, en cualquier orden.
   - `internal`: las dos cuentas son de la misma conexión bancaria, ninguna pata tiene contraparte (ni nombre ni cuenta en `creditor`/`debtor`) y el concepto de una nombra la otra cuenta (su `details`/`product` o la parte tras «Banco · » de su nombre), p. ej. «To EUR Gastos» ↔ hucha «Gastos» de Revolut.
   - `concept`: payee, concepto o `bank_transaction_code.code` contienen `TOP UP`/`TOPUP`, `RECARGA`, `TRASPASO`, `CUENTA(S) PROPIA(S)`, `ENTRE CUENTAS`, `MISMO TITULAR` o el nombre del banco de la otra cuenta (si es distinto del propio).
4. **Selección**: se ordenan (claras primero, más señales, menos días de diferencia, más recientes) y cada movimiento entra en una sola pareja.
5. **Clara** = única + ≥ 1 señal. Se convierte sola si además las dos patas están **sin categoría** (respeta lo que el usuario ya decidió) y, durante la sincronización, si la fecha más reciente cae en los últimos 30 días. El resto son sugerencias.

Conversión (`convert`): en una transacción, ambas filas pasan a `kind = 'transfer'`, `category_id = NULL`, mismo `transfer_group_id` nuevo, `transfer_source` (`auto` o `confirmed`) y `transfer_detected_at`. Importe, fecha, cuenta, payee y raw no cambian. Si el ingreso era una nómina que abrió periodo, `PeriodService::rebuild()`.
Deshacer (`undo`, solo con `transfer_source` no nulo): las patas del banco vuelven a `expense`/`income` según el signo, sin categoría ni grupo; las patas creadas a mano se borran del todo; si eran dos patas del banco se guarda la exclusión.
Cuenta sin conexión (`link`): la cuenta destino debe ser propia, no archivada y sin conexión bancaria. El importado pasa a pata (`transfer_source = 'linked'`) y se crea la contraparte `source = 'manual'` con importe opuesto, misma fecha y el nombre de la cuenta del banco como payee.
Inmutabilidad: `PATCH` sigue rechazando cambios de cuenta, tipo, importe o fecha de un importado; `TransferService::update` además rechaza importe y fecha si alguna pata es del banco. El tipo solo cambia por estas vías.

Enlace automático con cuenta manual (PRD FI-BK-15): tras las parejas, cada importado sin categoría que no está en ninguna pareja, sin contraparte en el raw y con concepto `TO|FROM|HACIA|DESDE X` (en el sentido de su signo) se enlaza con `link(..., TransferSource::Auto)` si X coincide con el nombre normalizado de **exactamente una** cuenta manual no archivada (nombre completo o la parte tras « · »). Al deshacerlo se guarda la exclusión `(id, id)`, que marca el movimiento como «no enlazar».

Cuándo corre: al final de `BankSyncService::sync()` (ventana de 30 días, guarda el número de conversiones en `bank_connections.last_sync_transfers`) y con `php artisan finance:detect-transfers [--dry-run] [--user=]` sobre todo el histórico. Es idempotente: lo convertido ya no es candidato y lo excluido no vuelve.

Las transferencias ya quedan fuera de ingresos, gastos, presupuestos y periodos porque todos filtran por `kind IN ('expense','income')` y `PeriodService::isPayroll()` exige `kind = 'income'`.

### 4.1.3 Recurrencia (Core) y generación de tareas (PRD §8)

**Motor de repetición** en `Core/Recurrence`, independiente de cualquier módulo (no conoce modelos; lo pueden usar Tareas, Notas o Finanzas). Envuelve `rlanvin/php-rrule` y solo admite el subconjunto que ofrece el editor: `FREQ` (`DAILY|WEEKLY|MONTHLY|YEARLY`), `INTERVAL` (1–365), `BYDAY`, `BYMONTHDAY`, `BYMONTH`, `BYSETPOS`. `DTSTART`, `UNTIL` y `COUNT` van aparte (columnas), no dentro del texto. Todas las fechas son días en `Europe/Madrid`.

```php
final readonly class RecurrenceRule {
    public static function parse(string $rule, CarbonImmutable $start, ?CarbonImmutable $until = null, ?int $count = null): self; // InvalidArgumentException si no es válida
    public static function isValid(string $rule): bool;
    public function between(CarbonImmutable $from, CarbonImmutable $to): array;   // list<CarbonImmutable>, ambos inclusive
    public function next(CarbonImmutable $from, int $limit): array;               // las $limit primeras >= $from
    public function frequency(): string;  public function interval(): int;
    public function part(string $name): ?string;
    public function toString(): string;   // texto normalizado: 'FREQ=WEEKLY;BYDAY=MO,TH'
}
final class RecurrenceDescriber {
    public static function describe(RecurrenceRule $rule): string;                 // 'Cada 2 semanas, el sábado'
    public static function afterDone(int $days): string;                          // '10 días después de completarla'
    public static function ending(?CarbonImmutable $until, ?int $count): ?string; // 'hasta el 9 nov' | '10 veces'
    public static function shortDate(CarbonImmutable $date): string;              // '9 nov'
}
```

**Generación** (`Modules/Tasks/Domain/Services/OccurrenceGenerator`):

- Cada plantilla guarda `generated_through`: todas las ocurrencias con fecha ≤ ese día ya se procesaron. En cada pasada se calculan las de `(generated_through, hoy + lead_days]` y se avanza `generated_through` hasta ese horizonte. Al crear una plantilla vale ayer (no se generan fechas pasadas de un `dtstart` antiguo); al reanudarla, también (lo que tocó en pausa no se recupera ni se registra).
- Idempotente: único `(template_id, occurrence_date)` en `tasks.tasks`, bloqueo `FOR UPDATE` de la plantilla y se saltan las fechas que ya tienen fila.
- Política *Sustituir* (`replace`): solo la última fecha jugable se crea abierta; las intermedias se guardan como `skipped` con `skip_reason = 'missed'` (si ya pasaron) o `'replaced'`, y la abierta anterior pasa a `skipped/replaced`. *Acumular* crea todas abiertas.
- Fechas saltadas (`task_template_exceptions`, el EXDATE): al llegar su día se guarda una fila `skipped/manual` y no se toca la abierta anterior. Saltar una fecha que ya tiene tarea omite esa tarea.
- Tipo "tras completarla" (`after_done_interval_days`, sin `rrule`): `next_due_date` es la siguiente fecha. Se genera cuando `next_due_date − lead_days ≤ hoy` y no hay ninguna abierta; al crearla pasa a `null`. Completar u omitir pone `next_due_date = hoy + intervalo` (y genera si ya toca); deshacer la vuelve a `null`. `until`/`count` cortan la serie.
- Una tarea generada copia título, notas, hora, importancia y subtareas de la plantilla. Editar la plantilla solo afecta a las futuras; con `apply_to_open` copia título, notas, lista, hora e importancia a las abiertas. Las hechas nunca cambian.
- Historial por ocurrencia: cada fecha procesada deja una fila (`open`, `done` o `skipped` con motivo), base del historial de la plantilla y de la conversión a hábito (PRD TA-PL-09, §4.1.5).
- Dos disparadores con el mismo código: `tasks:generate` (diario 00:05) y la **puesta al día perezosa** al pedir Hoy, Próximas o los contadores de Pendientes (`catchUp($user)`, memorizado por petición).

**Pendientes y aviso de las 20:00**: `TasksPendingItems` implementa `PendingItemsProvider` con el tipo `overdue_task` (abiertas con `due_date < hoy`; acción en línea Hecha / Pasar a hoy / Omitir) y además `Core/Pending/DailyDigestContributor`:

```php
interface DailyDigestContributor { public function digestCounts(User $user): array; } // ['task_due_today' => 2]
```

`PendingRegistry::digest()` suma a los contadores de Pendientes lo que aportan estos contribuidores y `SendPendingDigests` lo usa, así las tareas abiertas de hoy entran en el aviso ("Tienes 1 tarea vencida y 2 tareas de hoy por hacer") sin aparecer en Pendientes.

Un módulo que no tiene Pendientes puede añadir frases sueltas al mismo aviso con `Core/Pending/DigestLineProvider` (`moduleId()`, `digestLines(User): list<string>`), registrado con `PendingRegistry::registerDigestLines(...)`. Las líneas van detrás de la frase de Pendientes ("Tienes 1 tarea de hoy por hacer. Te quedan 2 hábitos de hoy"); si solo hay líneas, el aviso se manda igual, con el título "Hábitos de hoy" y la URL `/habitos/hoy`. Lo usa Hábitos (§4.1.5).

### 4.1.4 Notas: sincronización y reposición (PRD §9)

Notas es el único módulo que funciona sin conexión (ADR-014). La app escribe siempre en su caché local y encola el cambio; el servidor aplica la cola con las mismas reglas.

- **Operaciones**: `{id (UUID v7 del cliente), type, at, payload}`. Tipos: `folder.upsert|delete`, `note.upsert|purge`, `item.upsert|delete`, `product.upsert|delete`, `section.upsert|delete` y `shopping.finish`. Los upserts son parciales (solo se escriben las claves presentes) y crean la fila si no existe. `POST /notes/sync` las aplica en orden, cada una en su transacción, y devuelve el resultado de cada una más el snapshot completo.
- **Idempotencia**: cada id de operación se guarda en `notes.sync_operations` con su resultado; reenviarla devuelve `duplicate`.
- **Conflictos**: último en escribir gana por fila con `updated_at = at` de la operación; una operación más antigua que la fila vuelve como `stale`. Borrados, purgas y `shopping.finish` siempre se aplican. Los efectos laterales (mover el contenido de una carpeta borrada, quitar `is_primary` a otra lista, la fecha de compra) no tocan `updated_at`, para no invalidar ediciones offline anteriores.
- **Reposición** (sin jobs ni RRULE): un producto con `restock_mode = every_trip` toca justo después de cada compra; uno `interval`, cuando `fecha local (Europe/Madrid) de last_bought_at + restock_interval_days <= hoy`. Si toca, no está en la lista y `restocked_for` no es su ciclo (`{product_id}:{epoch de last_bought_at}`), se añade un elemento con id **UUID v5** del ciclo (namespace `6f0b5c3e-2d4a-5b8e-9c1f-7a3d2e1b0c9d`) y se apunta el ciclo en `restocked_for`. El servidor lo evalúa al construir el snapshot y tras `shopping.finish`; la app, al abrir la lista, al terminar compra y al recibir un snapshot. El id determinista evita duplicados entre los dos lados y `restocked_for` hace que un elemento repuesto y borrado no vuelva en el mismo ciclo. Los casos compartidos viven en `backend/app/Modules/Notes/tests/Fixtures/restock_cases.json` y los comprueban Pest y `flutter test`.
- **Terminar compra**: `shopping.finish {note_id, item_ids, finished_at}` borra los elementos del carro, pone `last_bought_at = finished_at` (a segundos) y suma `times_bought` a sus productos, y repone. Deshacer en la app manda operaciones compensatorias (restaura los elementos y `last_bought_at`, `times_bought` y `restocked_for` vía `product.upsert`, y borra lo repuesto).
- **Búsqueda**: `notes.immutable_unaccent()` (envoltorio `IMMUTABLE` de `unaccent`) alimenta columnas `tsvector` generadas en español sobre título + cuerpo y sobre cada elemento, con índices GIN. La consulta convierte cada palabra en prefijo (`palabra:*`) y añade un `ILIKE` sin acentos de respaldo. `NotesSearcher` reutiliza la consulta para la búsqueda global.
- Notas no aporta nada a Pendientes ni al aviso de las 20:00.

### 4.1.5 Hábitos: evaluación, descansos y conversión (PRD §10)

Nada de lo que se ve en Hábitos se guarda: periodos, estado, racha y constancia se calculan al leer (ADR-015). Con un usuario son unos cientos de filas por hábito y año.

- **Línea de tiempo** (`Domain/Evaluation/Timeline`): tipo, `start_date`, día de parada (el local de `min(paused_at, archived_at)`), objetivos ordenados por `valid_from`, valores por fecha y descansos (los del hábito más los globales). `goalOn(día)` es el último objetivo con `valid_from ≤ día` (o el primero).
- **Periodos** (`HabitEvaluator::periods`): de `start_date` a `min(hoy, parada − 1)`, en Europe/Madrid. Un objetivo diario da un periodo por día: `off` si el día no está marcado, `excused` si hay descanso y si no `met|missed|current`. Un objetivo semanal da un periodo de ese día al domingo (corta antes si un día posterior de la semana pasa a objetivo diario) y se evalúa con el objetivo vigente al final del periodo, o hoy si está en curso. Sí/No semanal cuenta días con valor > 0; Cantidad y Evitar suman.
- **Semanas incompletas**: con `d` días disponibles (dentro del seguimiento y sin descanso) y `d < 7`, el objetivo es `min(objetivo, d)` en Sí/No y `objetivo × d / 7` en Cantidad; el máximo de Evitar no cambia. Con `d = 0` el periodo es `excused`.
- **Estado**: Sí/No y Cantidad cumplen con `valor ≥ objetivo`; si no, `missed` al cerrar y `current` mientras dura. Evitar falla en cuanto `valor > máximo` (también el periodo en curso), cumple al cerrar y si no está `current`.
- **Estadísticas** (`HabitStats`): constancia = cumplidos / (cumplidos + no cumplidos) de los periodos que terminan desde el lunes de hace 4 semanas; el periodo en curso solo entra si ya está `met`. Racha = `met` seguidos desde el final saltando `off`, `excused` y `current`; mejor racha, la tirada más larga con su fecha final. Progreso usa la misma cuenta acotando por la fecha final del periodo al rango (semana, mes o año) y al anterior para la tendencia.
- **Objetivos con historial** (HA-04): cambiar periodo, objetivo o días hace `updateOrCreate` de una fila con `valid_from = max(hoy, start_date)` y borra las de fechas posteriores; si no cambia nada no se crea fila.
- **Pausar / archivar**: deja de evaluar desde ese día. Al reanudar o desarchivar se crea un descanso del hábito desde el día de parada hasta ayer, para que el hueco no cuente como no cumplido.
- **Registro**: `PUT /habits/{id}/entries/{fecha}` guarda el valor del día (único `habit_id + date`); valor 0 sin nota borra la fila. Deshacer en la app es otro `PUT` con el valor anterior.
- **Conversión de plantilla** (HA-TA-02): Hábitos no lee ni escribe el esquema `tasks`. Usa dos servicios del módulo Tasks: `Domain/Conversion/TemplateHistoryReader::read()` devuelve un DTO con la RRULE y las ocurrencias hasta hoy (`done`; `skipped` si se saltó a mano o es una excepción; `missed` el resto; la abierta de hoy se ignora) y `TemplateService::retire()` pausa la plantilla y borra sus tareas abiertas. El objetivo sale de la RRULE con `Core/Recurrence/RecurrenceRule`: `DAILY` → cada día, `WEEKLY` con o sin `BYDAY` (sin intervalo ni otras partes) → días concretos; lo demás es un 422. Hecha → registro con `source = task_import`; saltadas consecutivas → un descanso del hábito; `start_date` = primera ocurrencia. `habits.converted_from_template_id` guarda el id sin clave foránea.
- **Aviso de las 20:00** (HA-SH-02): `HabitsDigestProvider` implementa `DigestLineProvider` (no `PendingItemsProvider`: los hábitos nunca entran en Pendientes). "Te quedan N hábitos de hoy" con los diarios sin cumplir (sin Evitar) y "Correr: 1 de 3, quedan 2 días" para cada Sí/No semanal en riesgo (`días libres ≤ veces que faltan`, sin contar hoy si ya está registrado). Se apaga con el ajuste `digest`.
- `HabitsSearcher` aporta los hábitos a la búsqueda global (`/habitos/habito/{id}`).

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
| `sessions` | driver de sesión `database` (resto del cliente web, §6.4) |
| `personal_access_tokens` | tokens de Sanctum de la app iOS (uno por dispositivo, `name = 'carli iOS'`) |
| `user_modules` | user_id, module_id, enabled, settings jsonb |
| `push_devices` | user_id, token APNs (único), environment `sandbox`\|`production` |
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
--   transfer_source text NULL CHECK (transfer_source IN ('auto','confirmed','linked')),  -- §4.1.2; NULL = transferencia creada a mano
--   transfer_detected_at timestamptz NULL,
--   índice parcial de candidatas: (user_id, amount_cents, date) WHERE source = 'bank' AND kind IN ('expense','income') AND deleted_at IS NULL

-- bank_connections añade: last_sync_transfers int DEFAULT 0
-- bank_connections.accounts (snapshot por cuenta): uid, identification_hash, name (titular), details, product, iban enmascarado, currency, type

transfer_exclusions (                            -- parejas que no son transferencia (descartadas o deshechas)
  id uuid PK, user_id uuid FK,
  outgoing_transaction_id uuid FK transactions ON DELETE CASCADE,
  incoming_transaction_id uuid FK transactions ON DELETE CASCADE,
  timestamps,
  UNIQUE (outgoing_transaction_id, incoming_transaction_id)
)
```

Reglas de importación (F3):
- Los importados entran con `category_id NULL`.
- Borrado de importados con `deleted_at`. El upsert ignora `external_id` ya existentes **incluidos los borrados**, así no reaparecen (PRD FI-BK-06).
- Si el banco no da un id estable: `external_id = sha256(fecha|importe|concepto|n.º de ocurrencia ese día)`.
- Signo según `credit_debit_indicator` (DBIT → negativo). Solo `status = BOOK`.

### 5.4 Tareas (`tasks`)

| Tabla | Campos clave |
|---|---|
| `task_lists` | user_id, name, color, icon, is_default (único parcial por usuario: la *Bandeja*), sort_order, archived_at |
| `task_templates` | user_id, list_id, title, notes, subtasks jsonb (títulos), rrule (texto sin DTSTART) **o** after_done_interval_days (CHECK: exactamente uno), dtstart, until **o** count, policy (`replace`/`accumulate`), lead_days (0–365), due_time, important, generated_through, next_due_date, paused_at |
| `tasks` | user_id, list_id, template_id (null al borrar la plantilla), occurrence_date, title, notes, due_date, due_time, status (`open`/`done`/`skipped`), skip_reason (`manual`/`replaced`/`missed`), completed_at, skipped_at, important, sort. Único `(template_id, occurrence_date)`; índice parcial `(user_id, due_date) WHERE status = 'open'` para vencidas y Hoy; trigram en `title` para la búsqueda |
| `task_subtasks` | task_id, title, done_at, sort |
| `task_template_exceptions` | template_id, date (único): fechas saltadas, equivalente a EXDATE |

- *Vencida* no se guarda: `status = 'open' AND due_date < hoy` (como ADR-009).
- Ajustes del módulo en `user_modules.settings`: `default_list_id`, `default_policy`, `show_done_in_today` (`PATCH /api/v1/modules/tasks`).
- `DB_SEARCH_PATH` incluye `tasks` (por defecto `public,finance,tasks`) para que `migrate:fresh` limpie también este esquema.

### 5.5 Reglas de cálculo

| Concepto | Cálculo |
|---|---|
| Saldo de cuenta | `initial_balance_cents + SUM(amount_cents)` de movimientos no borrados (pendientes incluidos, mostrados aparte) |
| Patrimonio neto | Suma de saldos de cuentas con `include_in_net_worth` y no archivadas (tarjeta de crédito tiene saldo negativo) |
| Gasto propio por categoría | `SUM(-amount_cents)` de `kind='expense'` **menos** `shared_expense_shares.amount_cents`; transferencias excluidas; splits se reparten por `transaction_splits` |
| Presupuesto consumido | Gasto propio del periodo en la categoría y sus hijas (+ rollover del periodo previo si aplica) |
| Saldo con un contacto | `SUM(shares no liquidadas)` + deudas abiertas `owed_to_me` − deudas `i_owe` − pagos |
| Periodo financiero | `[start_date, end_date]`; el abierto llega hasta hoy. Un movimiento pertenece al periodo cuyo rango contiene su `date`. No se guarda `period_id` en `transactions`, así mover límites no obliga a reescribir movimientos |

### 5.6 Notas (`notes`)

Todas las marcas de tiempo son `timestamptz(6)` (la comparación de `updated_at` necesita las fracciones de segundo). Los ids los genera la app, salvo las secciones por defecto (UUID v5 de `section:{user_id}:{position}`).

```sql
note_folders (id, user_id, parent_id NULL → note_folders, name, position, timestamps)      -- sin ciclos (se valida al mover)
notes (id, user_id, folder_id NULL → note_folders ON DELETE SET NULL,
  type CHECK (type IN ('text','list','shopping')), title NULL, body NULL,
  pinned_at, archived_at, deleted_at NULL, checked_behavior CHECK IN ('move','inline'),
  is_primary bool, sort int, search tsvector GENERATED, timestamps)                       -- único is_primary por usuario
note_items (id, note_id → notes CASCADE, product_id NULL → shopping_products, text, quantity NULL,
  section_id NULL → shopping_sections, checked_at NULL, position, search tsvector GENERATED, timestamps)
shopping_sections (id, user_id, name, position, timestamps)                               -- 10 por defecto
shopping_products (id, user_id, note_id → notes CASCADE, name, name_normalized, section_id NULL,
  default_quantity NULL, restock_mode CHECK IN ('every_trip','interval','none'), restock_interval_days NULL CHECK (>= 1),
  last_bought_at NULL, times_bought, restocked_for NULL, timestamps)
sync_operations (id = id de la operación, user_id, type, status, processed_at)
```

Borrar una carpeta sube sus subcarpetas y notas a la carpeta padre. Las notas borradas quedan en la papelera (`deleted_at`) y se purgan a los 30 días al construir el snapshot. Los modelos usan nombres cualificados (`notes.notes`); `notes` está en `DB_SEARCH_PATH` para que `migrate:fresh` (y los tests) también vacíen el esquema.

### 5.7 Hábitos (`habits`)

```sql
habits (id, user_id, name, icon, kind CHECK IN ('check','quantity','avoid'), unit NULL,
  show_in_tasks bool, sort, start_date, preferred_time NULL, paused_at NULL, archived_at NULL,
  converted_from_template_id uuid NULL /* sin FK hacia tasks */, timestamps)
habit_goals (id, habit_id → habits CASCADE, valid_from, period CHECK IN ('day','week'),
  target numeric(12,2) CHECK (>= 0) /* mínimo; en avoid, máximo */,
  days_of_week smallint[] NULL /* ISO 1–7, solo con period = 'day' */, timestamps)       -- único (habit_id, valid_from)
habit_entries (id, habit_id → habits CASCADE, date, value numeric(12,2) CHECK (>= 0), note NULL,
  source CHECK IN ('manual','task_import','health'), timestamps)                        -- único (habit_id, date)
habit_breaks (id, user_id, habit_id NULL → habits CASCADE /* NULL = todos */, from_date, to_date CHECK (>= from_date), timestamps)
```

- El primer objetivo tiene `valid_from = start_date`. Sí/No diario siempre guarda `target = 1`; una lista con los 7 días se guarda como `NULL`.
- Ajustes del módulo en `user_modules.settings`: `show_in_tasks` (fila de anillos en Hoy de Tareas), `digest` (línea en el aviso de las 20:00) y `week_start` (`monday`, fijo en la v1).
- Los modelos usan nombres cualificados (`habits.habits`); `habits` está en `DB_SEARCH_PATH` (por defecto `public,finance,tasks,notes,habits`) para que `migrate:fresh` y los tests vacíen el esquema.

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
| POST | `/transfers/suggestions/confirm` | `{ outgoing_transaction_id, incoming_transaction_id }` convierte la pareja (`transfer_source = 'confirmed'`); 201 con `{ transfer_group_id, from, to }` |
| POST | `/transfers/suggestions/dismiss` | Mismo cuerpo; guarda la exclusión |
| POST | `/transactions/{id}/convert-to-transfer` | `{ account_id }` de una cuenta manual; crea la contraparte (`linked`) |
| POST | `/transactions/{id}/undo-transfer` | Deshace una transferencia detectada, confirmada o enlazada; devuelve los movimientos del banco restaurados |
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

En F3, `GET /transactions` añade los filtros `source` y `uncategorized=1`, y cada movimiento lleva `transfer_source`, `transfer_detected_at` y `transfer_undoable`. `GET /bank/connections` lleva `last_sync_transfers`.

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

### 6.3 Tareas (`/api/v1/tasks`)

Middleware `module:tasks` + `EnsureTasksInitialized` (crea la Bandeja la primera vez).

| Método | Ruta | Notas |
|---|---|---|
| GET | `/today` | `{date, overdue[], today[], done[], progress: {done, total}}`. Pone al día las plantillas antes de responder |
| GET | `/upcoming?days=14` | Un elemento por día: `{date, tasks[], occurrences[]}`; las ocurrencias son virtuales (plantillas activas, sin las saltadas), no se guardan |
| GET/POST/PATCH/DELETE | `/lists[/{id}]` | Con `open_tasks_count`. `PATCH {archived}` archiva; la Bandeja no se archiva ni se borra; solo se borran listas vacías. `?archived=1` incluye las archivadas |
| PUT | `/lists/order` | `{ids: []}` |
| GET | `/tasks?list_id=&status=open\|done\|all&q=&from=&to=` | Paginado (100). `done` ordena por `completed_at` (registro de hechas) |
| POST/GET/PATCH/DELETE | `/tasks[/{id}]` | Alta rápida: `{title, due_date?, due_time?, list_id?, important?, subtasks?: []}`. Sin fecha no hay hora |
| POST | `/tasks/{id}/complete`, `/reopen`, `/skip`, `/postpone {date}` | Completar/omitir una de "tras completarla" programa la siguiente |
| POST/PATCH/DELETE | `/tasks/{id}/subtasks[/{subtask}]` | `{title}`, `{done}`; marcarlas todas no completa la tarea |
| GET/POST/PATCH/DELETE | `/templates[/{id}]` | Frecuencia: `rrule` **o** `after_done_interval_days`, más `dtstart`, `until` **o** `count`. Respuesta con `frequency_text`, `ending_text`, `next_date`, `upcoming_dates` (5), `skipped_dates`, `open_task_id`. `PATCH … {apply_to_open: true}`; `DELETE …?delete_open=1` |
| POST | `/templates/{id}/pause`, `/resume`, `/skip {date}`, `/unskip {date}` | |
| GET | `/templates/{id}/history` | Últimas ocurrencias + `{done, window}` para "Hecha 8 de las últimas 10" |
| POST | `/templates/preview` | `{rrule` o `after_done_interval_days`, `dtstart?, until?, count?}` → `{description, ending, dates[5]}` para el editor |

Búsqueda global: `TasksSearcher` devuelve plantillas (`/tareas/plantillas/{id}`) y tareas (`/tareas/tarea/{id}`).

### 6.4 Restos del cliente web

El backend todavía conserva piezas del cliente Angular, retirado el 2026-10-26. Ningún cliente las usa; se pueden quitar cuando convenga:

- Sesión de Sanctum por cookie: `statefulApi()` en `bootstrap/app.php`, `SANCTUM_STATEFUL_DOMAINS`, `SESSION_*`, `/sanctum/csrf-cookie` y la tabla `sessions`.
- Rutas web de Fortify: `POST /login`, `/logout`, `/two-factor-challenge`, `/forgot-password`, `/reset-password` y `/user/*` (Caddy aún las pasa al backend).
- `GET/DELETE /api/v1/me/sessions[/{id}]` y `POST /me/sessions/logout-others` (sesiones de navegador).
- El callback del banco redirige a la web cuando falta `return_to`.
- La preferencia `sidebar_collapsed` en `PATCH /me/preferences`.
- Las URLs de las notificaciones guardadas se generan con el formato de rutas de la web; la app las traduce a sus rutas en `core/notifications/notification_route.dart`.

### 6.5 Notas (`/api/v1/notes`)

| Método | Ruta | Notas |
|---|---|---|
| GET | `/snapshot` | Carpetas, notas (con elementos, incluidas archivadas y papelera), secciones y productos. Repone antes de responder |
| POST | `/sync` | `{operations: [...]}` (máx. 500) → `{results: [{id, status: applied|duplicate|stale|rejected, error}], data: snapshot}`. Un error en una operación no falla el lote; el 422 es solo para el sobre |
| GET | `/search?q=&limit=` | `[{id, type, title, snippet, folder_path: ["Casa","Reformas"], archived, updated_at}]` |

`POST /sync` no pasa por el middleware que recorta textos y convierte `''` en `null`: los cuerpos se guardan tal cual y un elemento de lista puede crearse vacío. Ajustes del módulo en `user_modules.settings` (`checked_behavior` por defecto).

### 6.6 Hábitos (`/api/v1/habits`)

Middleware `module:habits`. Las fechas van en `Y-m-d` y los días se interpretan en Europe/Madrid.

| Método | Ruta | Notas |
|---|---|---|
| GET | `/today` | `{date, on_break, summary: {done, total, consistency}, habits[]}`. Solo los activos que se evalúan hoy (sin días no marcados ni en descanso). Cada hábito lleva el periodo en curso: `period`, `period_start/end`, `target` (prorrateado), `value`, `today_value`, `today_note`, `status`, `met`, `over`, `progress`, `days_left`, `streak`, `streak_unit`, `consistency`. `summary` no cuenta los Evitar. Lo usan Hoy de Hábitos, la tarjeta de Inicio y la fila de Hoy de Tareas |
| GET | `/` | Todos (activos, pausados y archivados) con `consistency`, `streak` y `week[7]` (`{date, state}`, estados `done|miss|today|future|off|rest|none`) |
| POST/GET/PATCH/DELETE | `/[{id}]` | Alta: `{name, icon (set cerrado), kind, unit?, period, target?, days_of_week?, start_date?, preferred_time?, show_in_tasks?}`; `kind` no se cambia después. El detalle añade `stats` (constancia 4 semanas y desde el inicio, racha, mejor racha y su fecha), `goals[]` (historial), `weeks[8]` (`{start, value, target}`) y `today` |
| POST | `/{id}/pause`, `/resume`, `/archive`, `/unarchive` | Reanudar crea el descanso de los días parado |
| PUT | `/order` | `{ids: []}` |
| GET | `/{id}/calendar?month=Y-m` | `{month, days[]: {date, state, value, note}}` |
| PUT/DELETE | `/{id}/entries/{fecha}` | `{value, note?}`; 422 si es futura o anterior al inicio, o un Sí/No distinto de 0/1. Devuelve `{entry, today}` |
| GET | `/progress?range=week\|month\|year&date=` | `{from, to, consistency, met, total, previous_consistency, trend, columns[], habits[]}`; cada hábito con `consistency`, `trend` (puntos frente al periodo anterior) y `cells` (por día; en `year`, `{month, consistency}`) |
| GET/POST/PATCH/DELETE | `/breaks[/{id}]` | `{from_date, to_date, habit_id?}` (`NULL` = modo descanso global) |
| POST | `/breaks/{id}/end` | Lo acorta hasta ayer, o lo borra si aún no ha empezado |
| GET | `/conversions/{template}` | Vista previa: objetivo deducido, `done/skipped/missed`, constancia y racha de partida y `cells` de 8 semanas. 404 si la plantilla no es tuya o Tareas está desactivado; 422 si no es diaria o semanal |
| POST | `/conversions` | `{template_id, name?, icon?, show_in_tasks?}` → detalle del hábito creado (201) |

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
│   ├── finance/
│   │   ├── data/         # FinanceApi, modelos, providers, repositorios, Enable Banking
│   │   ├── screens/      # resumen, movimientos, presupuestos, cuentas, categorías, recurrentes, objetivos, deudas, compartidos, ajustes, bancos
│   │   └── ui/           # widgets propios del módulo (transaction-row, budget-line, period-selector, tarjeta de Inicio…)
│   ├── tasks/
│   │   ├── data/         # TasksApi, modelos, providers (un contador de cambios refresca todas las vistas), TaskActions, FrequencyDraft (RRULE ↔ editor)
│   │   ├── screens/      # Hoy, Próximas, Listas (+ lista, hechas, archivadas), Plantillas, editor de plantilla, detalle, alta rápida, ajustes
│   │   └── ui/           # fila de tarea con check y deslizar para posponer, tarjeta de Inicio, acción en Pendientes, rutas
│   └── habits/
│       ├── data/         # HabitsApi, modelos, providers (contador de cambios), HabitActions, formatos
│       ├── screens/      # Hoy, Hábitos, Progreso, detalle, editor, ajustes
│       └── ui/           # anillo, puntos de día, hoja de registro, descansos, tarjeta de Inicio, fila de Hoy de Tareas, conversión de plantilla
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
| `drift`, `drift_flutter`, `uuid` | Caché offline de Notas y ids de cliente (UUID v7 / v5), §7.6 |

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
- Push (APNs): al iniciar sesión la app pide permiso, obtiene el token del dispositivo y lo registra con `POST /api/v1/push-devices {token, environment}` (`sandbox` si el perfil embebido tiene `aps-environment = development`, `production` si no); lo vuelve a enviar al volver a primer plano y lo borra con `DELETE /push-devices` al cerrar sesión. El backend firma un JWT ES256 con la clave `.p8` (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, secreto `/run/secrets/apns.p8`) y envía por HTTP/2; si APNs responde 410 o `BadDeviceToken` borra el token. Cada push lleva `url`; tocarla abre la ruta equivalente de la app (`notification_route.dart`) o la bandeja.
- Enable Banking: `POST /bank/connections` (o `/renew`) con `return_to: app` → `FlutterWebAuth2.authenticate(url, callbackUrlScheme: 'carli')`. El backend cierra el flujo redirigiendo a `carli://bank/callback` y la app abre la pantalla de vinculación.
- Dinero en céntimos (`int`) en toda la app; `CarliMoneyInput` devuelve céntimos.
- Formularios y altas en sheets (`showCarliSheet`, `showFullSheet`); confirmaciones con `CupertinoAlertDialog`; borrado con "Deshacer" en toast.
- Modelos y parseo JSON escritos a mano en `modules/*/data` (sin generación de código).

### 7.5 Rutas

Shell con `StatefulShellRoute.indexedStack`: cada pestaña conserva su pila (las de Notas, en §7.6).

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
/tareas                         → /tareas/hoy
/tareas/hoy, /tareas/proximas, /tareas/listas[/:id|/hechas|/archivadas], /tareas/plantillas   pestañas de Tareas
/tareas/tarea/:id, /tareas/plantillas/nueva, /tareas/plantillas/:id, /tareas/ajustes          fuera del shell
/habitos                        → /habitos/hoy
/habitos/hoy, /habitos/lista, /habitos/progreso                                                pestañas de Hábitos
/habitos/habito/:id[/editar], /habitos/nuevo, /habitos/ajustes                                 fuera del shell
/dev/catalogo                   solo en debug
```

Dentro de `/tareas` la barra muestra Inicio · Hoy · Próximas · Listas · Plantillas y el "+" abre el alta rápida de tarea (`ShellContext.tasks`).

El botón "+" flotante abre la hoja de nuevo movimiento desde cualquier pestaña. La pestaña Más muestra el contador de Pendientes.

### 7.6 Notas offline (`modules/notes`)

- **Caché**: base SQLite con `drift` (`data/local_db.dart`, código generado en `local_db.g.dart` con `dart run build_runner build`). Tablas espejo de las del servidor más `pending_operations` (la cola).
- **Escrituras**: `NotesActions` construye la operación, `NotesStore.record()` la aplica a la caché y la encola en la misma transacción, y `NotesSync` la envía con un pequeño retardo. Las pantallas leen un único `notesIndexProvider` (stream de drift), así que reaccionan al instante con o sin red.
- **Sincronización**: con cola, `POST /notes/sync`; sin cola, `GET /notes/snapshot`. La respuesta sustituye la caché y se vuelven a aplicar las operaciones que entraron mientras tanto. Sin red (`DioException` sin respuesta) la cola espera y se reintenta cada 20 s, al volver a primer plano y con cada cambio; la app muestra "Sin conexión" en Notas y Compra. Al cerrar sesión se vacía la base local.
- **Búsqueda**: online usa `GET /notes/search`; sin red, una búsqueda local sin acentos sobre la caché.
- Secciones del súper para productos nuevos: diccionario de palabras clave en la app (`data/section_guess.dart`); después se aprende por producto.
- Rutas: `/notas` (Notas: `/n/:id`, `/carpeta/:id`, `/archivadas`, `/papelera`, `/ajustes`) y `/compra` (lista principal). La barra contextual es Inicio · Notas · Compra; "+" abre el selector de tipo o enfoca el alta de producto. El editor de una nota (`/notas/n/:id`) oculta la barra.

### 7.7 Hábitos (`modules/habits`)

- Online, como Tareas: un `habitsChangesProvider` (contador) refresca Hoy, la lista, el detalle, el calendario, Progreso, la tarjeta de Inicio y la fila de Tareas tras cada cambio. Todas las mutaciones pasan por `HabitActions`; registrar muestra un toast de 4 s con "Deshacer" (un `PUT` con el valor anterior).
- Anillo (`HabitRing`, sobre `CarliRings`): siempre en ember (`colors.rings.first`) con el icono neutro. Un toque marca o desmarca un Sí/No y suma 1 en Cantidad y Evitar; mantener pulsado abre la hoja de registro (−/+, valor exacto, día y nota).
- Integración con el shell: `ShellContext.habits` (Inicio · Hoy · Hábitos · Progreso, "+" = nuevo hábito), `HabitsHomeCard` en Inicio y `HabitsTasksRow` en Hoy de Tareas. La fila solo aparece con el módulo activo y el ajuste `show_in_tasks`, muestra los pendientes de hoy con `show_in_tasks` y nunca los Evitar, y no suma a "3 de 7". El editor de plantilla ofrece "Convertir en hábito" cuando la RRULE es diaria o semanal (`canConvertToHabit`).
- Iconos: set cerrado de 32 nombres de `icon_names.dart` (el backend valida la misma lista en `HabitIcons`).

## 8. Procesos en segundo plano

| Tarea | Frecuencia | Qué hace |
|---|---|---|
| `finance:materialize-recurring` | Diario 06:00 | Crea movimientos de reglas con `next_occurrence <= hoy` (confirmados si `auto`, pendientes si `confirm` o si la cuenta está conectada al banco) y avanza `next_occurrence`. Idempotente (clave única regla + fecha). |
| `finance:upcoming-charges` | Diario 09:00 | Push de cargos en `remind_days_before` días |
| Listener `TransactionSaved` | Evento | Recalcula consumo del presupuesto y notifica al cruzar 80/100 % (guardar umbral notificado por mes para no repetir) |
| Listener `PayrollRegistered` | Evento | Si el ingreso es de una categoría `opens_period`, está confirmado y han pasado ≥ N días desde el inicio del periodo abierto: cierra el actual (`end_date = fecha − 1`), abre uno nuevo y copia presupuestos, todo en una transacción. Al editar o borrar esa nómina, `PeriodService::rebuild()` recalcula límites. |
| `finance:payroll-overdue` | Diario 09:00 | Si hoy > `expected_end_date` + 1 y no hay periodo nuevo: push de aviso (PRD FI-PE-07) |
| `finance:weekly-summary` | Lunes 09:00 | Opcional |
| `finance:bank-sync` (F3) | 07:00, 13:00, 19:00 | Encola un job por conexión activa: trae movimientos desde `max(sync_from_date, último booking_date − 5 días)`, upsert por `external_id`, actualiza el saldo del banco. Respeta el límite PSD2 de 4 consultas/día sin usuario presente. Las alertas de presupuesto se evalúan una vez al final del job, no por movimiento. Después detecta transferencias de los últimos 30 días (§4.1.2). |
| `finance:refresh-bank-account-names` (F3) | A mano | Relee `/accounts/{uid}/details` de las cuentas vinculadas, guarda `details`/`product` en el snapshot y renombra a «Banco · details» solo las cuentas que conservan el nombre por defecto antiguo («Banco titular»); `--dry-run`. Al renovar la conexión se aplica el mismo renombrado con los datos nuevos |
| `finance:detect-transfers` (F3) | A mano | Reprocesa todo lo importado; `--dry-run` lista lo que convertiría y lo que quedaría como sugerencia |
| `tasks:generate` | Diario 00:05 | Pone al día todas las plantillas activas (§4.1.3). Idempotente; la misma puesta al día corre al abrir Hoy o Próximas |
| `core:pending-digest` | Diario 20:00 | Si `PendingRegistry::digest()` (Pendientes + tareas abiertas de hoy) suma > 0 o algún módulo aporta líneas (Hábitos, §4.1.5), un push con el resumen ("Tienes 7 movimientos por categorizar"); respeta las preferencias de notificación. Nunca por elemento ni por sincronización. Llega por APNs a los iPhone registrados |
| `finance:bank-consent-expiry` (F3) | Diario 09:00 | Push a 7 y 1 día de `valid_until`; marca `expired` al pasar |
| `backup:database` | Diario 03:00 | `pg_dump` → restic → almacenamiento externo; retención 7 diarios / 4 semanales / 12 mensuales |

Sin APNs configurado (`APNS_KEY_ID` vacío), los avisos de servidor solo se ven en la bandeja de notificaciones de la app.

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

App iOS: se compila con Flutter/Xcode y se instala en el dispositivo; `API_URL` (`--dart-define`) fija el backend en tiempo de compilación (por defecto producción, `https://carli.jotade.io/api`). `NSLocalNetworkUsageDescription` y `NSFaceIDUsageDescription` están en `Info.plist`.

Desarrollo local: `make up` levanta el stack en `localhost:8180`; `flutter run -d <simulador> --dart-define=API_URL=http://127.0.0.1:8180/api` para la app.

## 11. Calidad y testing

| Capa | Herramienta | Cobertura mínima esperada |
|---|---|---|
| Backend unit/feature | Pest + `RefreshDatabase` sobre Postgres real (no SQLite: se usan esquemas y pg_trgm) | Servicios de dominio (saldos, transferencias, recurrentes, presupuestos) al 90 %; todos los endpoints con un test feature |
| Backend estático | Larastan nivel 8+, Pint | CI falla si hay errores |
| App estático | `flutter analyze` (`flutter_lints`); `make test-app` lanza este y `flutter test` | Sin avisos |
| App unit/widget | `flutter test`, con el adaptador `FakeApi` de `test/support` en lugar del `HttpClientAdapter` de dio | Formatos, providers, componentes de `ui/`, pantallas del shell, de Finanzas y de Tareas |
| App integración | `integration_test/` en simulador contra un backend local real (puerto 8181, base de pruebas sembrada con `SEED_DEMO_USER=true php artisan migrate:fresh --seed`): `flutter test integration_test/<fichero> -d <simulador> --dart-define=API_URL=http://127.0.0.1:8181/api` | Login y flujos de Core |
| Capturas | `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screenshots*_test.dart` con `SCREENSHOT_DIR` (y `SHOT_THEME`, `SHOT_PREFIX`) | Revisión visual en claro y oscuro |
| Accesibilidad | `Semantics` en widgets de `ui/`, tamaños táctiles ≥ 44 pt, revisión con VoiceOver | Etiquetas en todos los controles icon-only, gráficos con vista tabla |

## 12. Plan de implementación sugerido

1. **Infra base**: monorepo, compose dev, Laravel vacío, CI.
2. **Core backend**: auth Sanctum/Fortify, usuarios, módulos, notificaciones DB.
3. **Design system** (`ui/`): tokens, tema, componentes base; catálogo en `/dev/catalogo` (solo debug).
4. **Shell de la app**: login, bloqueo, pestañas, Inicio, ajustes, tema.
5. **Finanzas MVP**: cuentas → categorías (seeder) → movimientos y transferencias → dashboard → presupuestos.
6. **Avisos**: bandeja de notificaciones, Pendientes y push por APNs.
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
- ADR-011 Aviso diario como notificación local mientras no haya APNs (sustituido el 2026-10-27 por push APNs con la cuenta de desarrollador de pago).
- ADR-012 Transferencias entre cuentas propias detectadas por emparejamiento (§4.1.2). Contexto: una recarga BBVA → Revolut entraba como gasto + ingreso e inflaba ambos. Decisión: convertir solo parejas claras (importe exacto, ≤ 3 días, candidato único en ambos sentidos, al menos una señal fuerte, sin categoría) y proponer el resto en Pendientes como estado calculado (coherente con ADR-009); las únicas filas nuevas son las exclusiones, para que deshacer y "No es transferencia" sean definitivos. El IBAN se compara enmascarado para no guardar IBAN completos. Descartado: emparejar por importe y fecha sin señales (falsos positivos con Bizums y devoluciones) y guardar sugerencias en tabla (se quedarían obsoletas al borrar o categorizar).
- ADR-013 Tareas repetitivas con RRULE (RFC 5545) y una fila por ocurrencia. Contexto: cron no expresa "cada 2 semanas desde el 4 de marzo" ni "el último viernes del mes", y hace falta el tipo "tras completarla". Decisión: la plantilla guarda una RRULE limitada al subconjunto del editor (motor en `Core/Recurrence` sobre `rlanvin/php-rrule`, reutilizable por otros módulos) o un intervalo en días desde que se completa; cada ocurrencia procesada se guarda como tarea (abierta, hecha u omitida con motivo) con clave única `plantilla + fecha`, y la generación es idempotente (job a las 00:05 + puesta al día perezosa, para que el Mac dormido no deje huecos). Las ocurrencias futuras de Próximas se calculan al vuelo. Descartado: expresiones cron (no cubren los casos), materializar el futuro (habría que regenerarlo al editar) y guardar solo la abierta (se pierde el historial que necesitará Hábitos).
- ADR-014 Notas funciona sin conexión: caché local (drift) y cola de operaciones idempotentes con id del cliente (UUID v7), sincronizada por lotes con `POST /notes/sync` y "último en escribir gana" por fila. Contexto: el backend vive en un Mac que se duerme y la lista de la compra se usa en el súper, a menudo sin cobertura. Es la única excepción a "sin offline"; el resto de módulos sigue online. La reposición se calcula igual en PHP y Dart con ids deterministas (UUID v5) para que los dos lados no dupliquen productos. Descartado: offline en toda la app (coste alto y sin necesidad fuera de Notas) y CRDTs (un solo usuario y un dispositivo).
- ADR-015 Hábitos se evalúa al leer, con historial de objetivos y sin vínculo vivo con Tareas. Contexto: un hábito se mide por constancia sobre periodos (día o semana, con objetivos flexibles, cantidades y máximos) y no vence; cambiar el objetivo no debe reescribir el pasado, y los descansos no deben romper rachas. Decisión: se guardan solo registros (uno por hábito y día), objetivos con `valid_from` y descansos; periodos, rachas y constancia se calculan en `HabitEvaluator`/`HabitStats` en cada lectura (Europe/Madrid, semanas de lunes a domingo, periodo en curso sin penalizar). Tareas y Hábitos se conectan solo por la fila de anillos de Hoy (la app llama a `/habits/today`) y por una conversión única de plantilla que lee el historial y pausa la plantilla a través de servicios del módulo Tasks, sin claves foráneas entre esquemas. Descartado: guardar el estado de cada periodo (habría que recalcularlo al editar el objetivo, un registro pasado o un descanso), modelar los hábitos con RRULE (no expresa "3 veces por semana" ni cantidades) y el vínculo vivo plantilla ↔ hábito (dos dueños de lo mismo y cambiar la semántica de Tareas).
