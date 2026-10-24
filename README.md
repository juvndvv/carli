# carli

Asistente personal modular (Finanzas, y más adelante Tareas, Salud, Hábitos y Notas).
Stack: Angular 22 · Laravel 13 · PostgreSQL 18. Autoalojada en VPS propio.

## Documentación

- [docs/PRD.md](docs/PRD.md): requisitos de producto (shell + módulo Finanzas, fases F0–F3).
- [docs/TRD.md](docs/TRD.md): arquitectura, modelo de datos, API, frontend, despliegue y plan de implementación.
- [docs/DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md): tokens (claro/oscuro), tipografía, componentes y patrones.
- [mockup/index.html](mockup/index.html): mockup navegable. Ábrelo en el navegador (funciona sin servidor). Prueba el tema (icono del monitor), el botón "+" y el ancho móvil.

## Puesta en marcha (Docker)

Requisitos: Docker con Compose v2 y `make`. Todo corre en contenedores: `postgres`, `app` (php-fpm), `worker` (colas), `scheduler` (tareas programadas), `caddy` (SPA + proxy FastCGI) y `backup` (pg_dump diario).

```sh
make setup        # crea .env desde .env.example, construye imágenes y genera APP_KEY y claves VAPID
make up           # levanta el stack (las migraciones se ejecutan al arrancar `app`)
make create-user  # crea tu usuario (no hay registro público)
```

Abre <http://localhost:8180>. Otros comandos:

| Comando | Qué hace |
|---|---|
| `make logs` | Logs en vivo (`make logs ARGS=app` para uno solo) |
| `make down` | Para y elimina los contenedores (los volúmenes se conservan) |
| `make migrate` | `php artisan migrate --force` en `app` |
| `make seed-demo` | Carga datos de demostración (`SEED_DEMO_USER=true`) |
| `make shell` | Shell dentro de `app` |
| `make test-backend` | Pest en una imagen `dev` contra la base `TEST_DB_DATABASE` (por defecto `personal_test`) |
| `make test-frontend` | Vitest (`ng test`) en un contenedor Node |
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
   SESSION_DOMAIN=app.example.com
   SESSION_SECURE_COOKIE=true
   SANCTUM_STATEFUL_DOMAINS=app.example.com
   VAPID_SUBJECT=mailto:tu@correo.com
   DB_PASSWORD=<contraseña larga>
   ```
   Cambia `DB_PASSWORD` antes del primer arranque (Postgres la fija al crear el volumen).
3. `make up` y `make create-user`. Caddy obtiene y renueva el certificado TLS automáticamente y activa HSTS.
4. Actualizar: `git pull && make up` (reconstruye las imágenes y migra al arrancar).

### Backups

El servicio `backup` hace un `pg_dump` diario a las 03:00 (Europe/Madrid) en `./backups` y conserva 7 diarios, 4 semanales y 12 mensuales. Si defines `RESTIC_REPOSITORY` y `RESTIC_PASSWORD` (y credenciales S3 si aplica) también sube una instantánea cifrada con restic con la misma retención.

Restaurar un dump:

```sh
docker compose exec -T postgres pg_restore --clean --if-exists --no-owner -U personal -d personal < backups/daily/personal-AAAA-MM-DD.dump
```
