# carli

Asistente personal modular (Finanzas, y más adelante Tareas, Salud, Hábitos y Notas).
Stack: app nativa iOS en Flutter (`app/`) · Laravel 13 (`backend/`) · PostgreSQL 18. Backend autoalojado en VPS propio.

## Documentación

- [docs/PRD.md](docs/PRD.md): requisitos de producto (shell + módulo Finanzas, fases F0–F3).
- [docs/TRD.md](docs/TRD.md): arquitectura, modelo de datos, API, app iOS, despliegue y plan de implementación.
- [docs/DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md): tokens (claro/oscuro), tipografía, componentes y patrones de la librería Ember en Flutter.
- [app/README.md](app/README.md): arranque y pruebas de la app iOS.
- [mockup/index.html](mockup/index.html): mockup navegable antiguo (tokens monocromos previos a Ember). Ábrelo en el navegador (funciona sin servidor).

## App iOS (Flutter)

Requisitos: Flutter 3.47 (Dart 3.13), Xcode y un simulador de iOS. Bundle id `dev.jotade.personal`, iOS 15+.

```sh
cd app
flutter pub get
flutter run -d <simulador> --dart-define=API_URL=http://<host>:8180/api
```

`API_URL` apunta al backend (por defecto `http://MacBook-Pro-van-Yurest.local:8180/api`, ver `lib/core/api/api_config.dart`). En builds de depuración hay un catálogo de componentes en `/dev/catalogo`.

| Comando (en `app/`) | Qué hace |
|---|---|
| `flutter analyze` | Análisis estático y lints |
| `flutter test` | Tests unitarios y de widgets (API simulada con el adaptador `FakeApi` de `test/support`) |
| `flutter test integration_test/<fichero> -d <simulador> --dart-define=API_URL=http://127.0.0.1:8181/api` | Tests de integración contra un backend local |
| `SCREENSHOT_DIR=<dir> flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screenshots<_x>_test.dart -d <simulador> --dart-define=API_URL=...` | Capturas de pantalla (`SHOT_THEME=light\|dark`, `SHOT_PREFIX` por `--dart-define`) |

Los tests de integración y las capturas usan el usuario demo: un backend local en el puerto 8181 contra la base de pruebas, preparada con `SEED_DEMO_USER=true php artisan migrate:fresh --seed`.

## Puesta en marcha (Docker)

Requisitos: Docker con Compose v2 y `make`. Todo corre en contenedores: `postgres`, `app` (php-fpm), `worker` (colas), `scheduler` (tareas programadas), `caddy` (TLS y proxy FastCGI de las rutas del backend; el resto responde 404) y `backup` (pg_dump diario).

```sh
make setup        # crea .env desde .env.example, construye imágenes y genera APP_KEY (y claves VAPID, que hoy no usa ningún cliente)
make up           # levanta el stack (las migraciones se ejecutan al arrancar `app`)
make create-user  # crea tu usuario (no hay registro público)
```

La API queda en <http://localhost:8180/api>; la app iOS la usa con `API_URL`. Otros comandos:

| Comando | Qué hace |
|---|---|
| `make logs` | Logs en vivo (`make logs ARGS=app` para uno solo) |
| `make down` | Para y elimina los contenedores (los volúmenes se conservan) |
| `make migrate` | `php artisan migrate --force` en `app` |
| `make seed-demo` | Carga datos de demostración (`SEED_DEMO_USER=true`) |
| `make shell` | Shell dentro de `app` |
| `make test-backend` | Pest en una imagen `dev` contra la base `TEST_DB_DATABASE` (por defecto `personal_test`) |
| `make test-app` | `flutter analyze` y `flutter test` en `app/` (necesita Flutter en el host) |
| `make backup` | Ejecuta un backup ahora |

La configuración de Laravel llega a los contenedores por variables de entorno desde el `.env` raíz; `backend/.env` no se copia a las imágenes. Postgres solo escucha en `127.0.0.1:55440` del host.

### Despliegue en un VPS con dominio

1. Apunta un registro DNS `A`/`AAAA` (p. ej. `app.example.com`) a la IP del VPS y abre solo los puertos 22, 80 y 443.
2. Clona el repo, ejecuta `make setup` y edita `.env`:
   ```dotenv
   SITE_ADDRESS=app.example.com
   APP_URL=https://app.example.com
   APP_BIND=0.0.0.0
   APP_PORT=80
   APP_HTTPS_PORT=443
   DB_PASSWORD=<contraseña larga>
   ```
   Cambia `DB_PASSWORD` antes del primer arranque (Postgres la fija al crear el volumen). `SESSION_*`, `SANCTUM_STATEFUL_DOMAINS` y `VAPID_*` siguen en `.env.example` como restos del cliente web; la app no los necesita.
3. `make up` y `make create-user`. Compila la app con `--dart-define=API_URL=https://app.example.com/api`. Caddy obtiene y renueva el certificado TLS automáticamente y activa HSTS.
4. Actualizar: `git pull && make up` (reconstruye las imágenes y migra al arrancar).

### Despliegue en AWS Lightsail (túnel de Cloudflare, sin puertos abiertos)

Producción corre en una instancia Lightsail (Ubuntu 24.04, 2 GB) con este mismo Compose; el tráfico entra por Cloudflare Tunnel, así que el firewall solo deja SSH.

1. Instala Docker (`curl -fsSL https://get.docker.com | sh`), añade 2 GB de swap y clona el repo.
2. Copia el `.env` y la clave de Enable Banking desde la máquina anterior. Conserva el mismo `APP_KEY`: sin él no se descifran los `session_id` de los bancos. Añade:
   ```dotenv
   APP_URL=https://carli.jotade.io
   COMPOSE_PROFILES=tunnel
   CLOUDFLARE_TUNNEL_TOKEN=<token del túnel>
   ```
   El hostname público del túnel debe apuntar a `http://localhost:8180` (`cloudflared` usa la red del host).
3. Restaura el último dump (ver [Backups](#backups)) y `make up`.
4. No tengas el mismo túnel conectado en dos máquinas: Cloudflare repartiría las peticiones entre dos bases de datos. Para `cloudflared` en la máquina anterior antes de arrancarlo aquí.

### Sincronización bancaria (Enable Banking, F3)

Opcional: sin configurar, la app funciona en manual y `Más → Ajustes de Finanzas → Bancos` responde que la conexión no está configurada.

1. Crea una aplicación en [Enable Banking](https://enablebanking.com) en modo *restricted* (gratis para cuentas propias) y enlaza en su panel las cuentas de Revolut, BBVA y MyInvestor.
2. Registra como redirect URL `https://<dominio>/api/v1/finance/bank/callback` (en local, `http://localhost:8180/api/v1/finance/bank/callback`).
3. Descarga la clave privada de la aplicación y guárdala **fuera del repo**, legible por el contenedor (p. ej. `/etc/personal-app/enable_banking.pem`, `chmod 644`).
4. En `.env`:
   ```dotenv
   ENABLE_BANKING_APP_ID=<id de la aplicación>
   ENABLE_BANKING_PRIVATE_KEY_FILE=/etc/personal-app/enable_banking.pem
   # ENABLE_BANKING_REDIRECT_URL=...   # por defecto ${APP_URL}/api/v1/finance/bank/callback
   ```
   Compose monta el fichero como Docker secret en `/run/secrets/enable_banking.pem` en `app`, `worker` y `scheduler`. La clave nunca se guarda en la base de datos; el `session_id` de cada conexión se guarda cifrado con `APP_KEY`.
5. `make up`. En la app el consentimiento se abre en `ASWebAuthenticationSession`: la app envía `return_to: app` al conectar o renovar y el callback HTTPS devuelve el control con `carli://bank/callback`.
6. El `scheduler` sincroniza a las 07:00, 13:00 y 19:00 (`finance:bank-sync`) y avisa a 7 y 1 día de que caduque el consentimiento (`finance:bank-consent-expiry`, 09:00). El botón "Sincronizar ahora" encola un job en el `worker`.

Para desarrollo sin Docker, define `ENABLE_BANKING_APP_ID` y `ENABLE_BANKING_PRIVATE_KEY_PATH` en `backend/.env`.

### Backups

El servicio `backup` hace un `pg_dump` diario a las 03:00 (Europe/Madrid) en `./backups` y conserva 7 diarios, 4 semanales y 12 mensuales. Si defines `RESTIC_REPOSITORY` y `RESTIC_PASSWORD` (y credenciales S3 si aplica) también sube una instantánea cifrada con restic con la misma retención.

Restaurar un dump:

```sh
docker compose exec -T postgres pg_restore --clean --if-exists --no-owner -U personal -d personal < backups/daily/personal-AAAA-MM-DD.dump
```
