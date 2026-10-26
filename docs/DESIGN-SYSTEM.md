# Design System · "Ember"

Design system propio de **carli**, el asistente personal. Desde el 26/10/2026 sigue el prototipo "Health Tracker" que Juanda dejó en `docs/Health Tracker.zip` (tokens en `ds/colors_and_type.css`, derivados del Yurest Design System): estética tipo Apple Fitness, fondo negro puro en oscuro y gris claro en claro, tarjetas grandes y redondeadas, títulos muy gruesos, etiquetas de sección en mayúsculas y un único acento rosa-rojo ("ember"). Sustituye a la dirección "Sol". Se implementa en `frontend/src/app/ui/` como componentes Angular standalone, con tokens en CSS custom properties y Tailwind CSS v4 (`@theme`) como capa de utilidades. El [mockup](../mockup/index.html) todavía usa los tokens monocromos antiguos.

## 1. Principios

1. **Neutros y un solo acento.** Negro, blanco y grises neutros, más el acento ember. El acento marca la acción principal, la pestaña activa, la selección, los enlaces de sección ("Ver", "Historial") y el logo. Como mucho una mancha grande de acento por pantalla (la acción principal).
2. **El color significa algo, y poco.** Fuera del acento, el color solo aparece en gráficos (identidad de categoría), en ingresos (verde) y en estados (aviso ámbar, excedido rojo). Los estados colorean el **número**, nunca la barra o el gráfico que lo acompaña. Un gasto normal se muestra en color de texto. El acento y el rojo de "excedido" son parecidos: un estado de error **siempre** lleva icono y texto, nunca solo color.
3. **Plano.** Las tarjetas se separan por el fondo y un borde de 1 px, sin sombra. Sombra solo en lo que flota (diálogos, menús, toasts).
4. **Redondeado y táctil.** Tarjetas de 22 px, botones y controles de 12 px (16 px el grande), avatares y FAB redondos. Objetivos táctiles ≥ 44 px.
5. **Números primero.** Cifras grandes en Geist con dígitos tabulares, peso 600, tracking negativo; la unidad va pequeña y en gris al lado ("78.3 kg", "1.284,50 €").
6. **Claro y oscuro de primera.** El oscuro es negro puro (`#000`) con tarjetas `#161616`; el claro es gris `#F5F5F7` con tarjetas blancas.

## 2. Tokens

### 2.1 Superficies y texto

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `--bg` | `#F5F5F7` | `#000000` | Fondo de la app |
| `--surface` | `#FFFFFF` | `#161616` | Tarjetas, sheets, bottom nav |
| `--surface-2` | `#F0F0F2` | `#1F1F1F` | Hover, buscador, segmentado, botón ghost, iconos |
| `--sidebar` | `#FFFFFF` | `#0A0A0A` | Barra lateral |
| `--border` | `#EBEBEB` | `#262626` | Bordes y divisores |
| `--text` | `#1F1F1F` | `#FFFFFF` | Texto principal |
| `--text-2` | `#666666` | `#A3A3A3` | Texto secundario, etiquetas de sección |
| `--text-3` | `#6E6E6E` | `#8A8A8A` | Ayudas, placeholders, ejes |

### 2.2 Acción y estados

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `--primary` | `#E5063F` | `#E5063F` | Ember: botón principal, chip activo, FAB, selección, logo |
| `--primary-hover` | `#D90033` | `#FA114F` | |
| `--primary-soft` | `#FFEBF0` | `#3A0A18` | Ítem de navegación activo, badge `primary`, filas seleccionadas |
| `--on-primary` | `#FFFFFF` | `#FFFFFF` | Texto sobre primario |
| `--primary-strong` | `#E5063F` | `#FA114F` | Barras de progreso `primary`, anillos, líneas de gráfico del acento |
| `--brand-ink` | `#D90033` | `#FF5C85` | Texto en color de acento (pestaña activa, "Ver todos"); AA sobre `--bg` y `--surface` |
| `--positive` | `#0F7B4A` | `#10B981` | Ingresos, variación favorable |
| `--warning` | `#B45309` | `#F59E0B` | Presupuesto 80–100 %, pendientes |
| `--negative` | `#C8281C` | `#ED5A46` | Excedido, errores, borrar |
| `--*-soft` | `#ECFDF0` · `#FFFBEB` · `#FEF3F2` | `#0F2E22` · `#3A2A0A` · `#3D1A16` | Fondos de badges de estado |
| `--focus-ring` | `rgba(229,6,63,.25)` | `rgba(255,92,133,.4)` | Anillo de foco 3 px |

El ember del prototipo es `#FA114F`, pero con texto blanco da 4,0:1 y no pasa AA; por eso el relleno es `#E5063F` (4,7:1) y `#FA114F` queda para hover y trazos en oscuro. Los estados siempre van con icono o texto, nunca solo color.

### 2.3 Datos y categorías

Paleta categórica de 8 colores en **orden fijo**, validada para daltonismo en pares adyacentes en ambos temas. Se usa **solo en gráficos y leyendas**; en listas los iconos de categoría son monocromos (círculo `--surface-2` + glifo `--text`). El color sigue a la categoría, no a su posición en un ranking; a partir de la 9.ª categoría se agrupa en "Otros".

| Slot | Claro | Oscuro |
|---|---|---|
| 1 azul | `#2A78D6` | `#3987E5` |
| 2 naranja | `#EB6834` | `#D95926` |
| 3 aqua | `#1BAF7A` | `#199E70` |
| 4 amarillo | `#EDA100` | `#C98500` |
| 5 magenta | `#E87BA4` | `#D55181` |
| 6 verde | `#008300` | `#008300` |
| 7 violeta | `#6250D6` | `#9085E9` |
| 8 rojo | `#E34948` | `#E66767` |

"Ingresos vs gastos": ingresos = slot 1, gastos = slot 2, con leyenda siempre visible.

Los módulos (Finanzas, Tareas, Salud, Hábitos, Notas) se distinguen por icono, no por color.

### 2.4 Tipografía

- Familia: **Geist** (variable, autoalojada en `public/fonts/Geist-Variable.woff2`, licencia OFL) con la pila del sistema de respaldo. El prototipo declara "Open Sauce One" para el cuerpo, pero no está en Google Fonts y en el prototipo nunca llega a cargarse (se ve la fuente del sistema), así que se usa Geist para todo.
- Números: `font-variant-numeric: tabular-nums` en importes, tablas y KPI.

| Token | Tamaño / línea | Peso | Uso |
|---|---|---|---|
| `display` | 36/42 · tracking −0.02em | 600 | Cifra héroe (patrimonio, importe en alta) |
| `h1` | 28/34 · −0.025em | 800 | Título de página ("Hola, Juanda") |
| `h2` | 16/24 | 600 | Título de tarjeta |
| `body` | 15/22 | 400 | Texto general |
| `body-strong` | 15/22 | 600 | Importes en listas, navegación activa |
| `small` | 13/18 | 400 | Secundario |
| `caption` | 12/16 | 500 | Ejes, badges |
| `eyebrow` | 12/16 · +0.08em · MAYÚSCULAS | 600 | Etiquetas de sección ("PRESUPUESTOS", "ESTA SEMANA"), en `--text-2` |

### 2.5 Forma, sombras y movimiento

- Radios: `--r-sm 6px` (tags, tooltips), `--r-md 12px` (inputs, filas), `--r-control 12px` (botones, segmentado, buscador; 16 px en botón grande), `--r-lg 22px` (tarjetas), `--r-xl 32px` (sheets móviles, diálogos), `--r-full 999px` (avatares, iconos circulares, FAB, switch, toast). Chips a 8 px.
- Iconos: Hugeicons (`@hugeicons/core-free-icons`, estilo stroke rounded), trazo 1.5, 18 px. Los nombres que usa la app (y que guarda la base de datos) siguen la nomenclatura kebab-case de siempre (`shopping-cart`, `piggy-bank`…) y se traducen al glifo de Hugeicons en `ui/icon/icon-set.ts` y `finance-icons.ts`; para añadir uno, se registra ahí con su equivalente.
- Sombras: ninguna en tarjetas. `--shadow-2` solo para diálogos, menús y FAB.
- Espaciado (px): `2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64`.
- Movimiento: `120ms` hover, `200ms ease-out` entrada de diálogos y sheets; respetar `prefers-reduced-motion`.

### 2.6 Layout y breakpoints

| Nombre | Ancho | Layout |
|---|---|---|
| `sm` | < 640 | Bottom nav (5 ítems) + FAB redondo ember, 1 columna, gutter 16 px; diálogos como sheet inferior |
| `md` | 640–1023 | Bottom nav, 2 columnas en dashboard |
| `lg` | ≥ 1024 | Sidebar 260 px gris claro sin borde, contenido máx. 1160 px, gutter 32 px |

## 3. Componentes (`ui/`)

| Componente | Notas de estilo |
|---|---|
| `ui-button` | `primary` (ember con texto blanco), `secondary` (borde), `ghost` (relleno `--surface-2`), `danger`; radio 12 (16 en `lg`, 52 px de alto); `sm/md/lg`; `icon-only` circular; estado `loading` |
| `ui-input`, `ui-textarea` | Borde fino, radio 12, foco oscureciendo el borde (sin halo de color) |
| `ui-search` | Rectángulo de radio 12 relleno `--surface-2` sin borde, icono a la izquierda (estilo "composer") |
| `ui-money-input` | Cifra display centrada, `inputmode="decimal"`, coma decimal, devuelve céntimos |
| `ui-select`, `ui-combobox` | CDK Overlay + Listbox; menú con `--shadow-2` y radio 16 |
| `ui-category-picker` | Cuadrícula de iconos circulares; el seleccionado se invierte (fondo `--primary`) |
| `ui-date-picker` | Chips "Hoy", "Ayer"; semana empieza en lunes |
| `ui-segmented` | Contenedor `--surface-2` de radio 12; opción activa blanca con texto oscuro en ambos temas y sombra mínima |
| `ui-chip` | Radio 8 con borde; activo = relleno `--primary` |
| `ui-card` | `--surface` sobre `--bg`, borde 1 px, radio 22, sin sombra |
| `ui-stat` | Etiqueta pequeña, valor 24/600, variación con icono + texto |
| `ui-progress` | 8 px. La barra nunca cambia de color por estado: `--text` en presupuestos y `--primary-strong` en objetivos y deudas. El aviso (80–100 %) y el exceso se marcan en la **cifra** ("141 / 150 €") con `--warning` o `--negative`, icono y peso 600 |
| `ui-badge` | neutral, positive, warning, negative |
| `ui-list-item` | Icono circular monocromo, título, subtítulo, valor a la derecha; hover `--surface-2` |
| `ui-dialog` / `ui-sheet` | Mismo contenido; sheet inferior en móvil con radio 28 |
| `ui-toast` | Píldora invertida (`--text` de fondo) con acción "Deshacer" |
| `ui-tooltip` | Invertido, radio 8 |
| `ui-tabs` | Subrayado en `--text` |
| `ui-empty-state`, `ui-skeleton`, `ui-avatar` | Monocromos |
| `ui-logo` | La carita de carli en ember (`--primary`) con ojos blancos (`--on-primary`); `size` en px (30 por defecto) |
| `ui-chart` | Wrapper Chart.js; único sitio con paleta categórica; leyenda, tooltip y vista tabla |
| `ui-nav-*` | sidebar, bottom-nav, topbar; bottom nav translúcida con desenfoque; ítem activo en `--brand-ink` (y fondo `--primary-soft` en la sidebar) |

## 4. Patrones de contenido

- **Importes**: `1.234,56 €` (es-ES con `useGrouping: 'always'`). Gastos con `−` en color de texto; ingresos con `+` en `--positive`; transferencias en `--text-2` sin signo.
- **Fechas**: cabeceras "Hoy", "Ayer", "Jueves 22 oct"; formularios `dd/mm/aaaa`.
- **Tono**: segunda persona, frases cortas. "Te quedan 120 € en Ocio".
- **Vacíos**: explicar la sección y ofrecer la primera acción.
- **Destructivo**: confirmar solo si no se puede deshacer; si se puede, borrar y ofrecer "Deshacer".

## 5. Accesibilidad

- Contraste AA en texto (4,5:1) y componentes (3:1) en ambos temas. `--text-3` está ajustado a `#6E6E6E` en claro (el `#8F8F8F` del prototipo da 3,2:1 y no pasa); no aclararlo más. Texto en color de acento siempre con `--brand-ink`, nunca con `--primary`.
- Foco visible siempre, orden lógico, `Esc` cierra diálogos, `cdkTrapFocus`.
- Gráficos con leyenda, tooltip y alternativa en tabla.
- `prefers-reduced-motion` y `prefers-color-scheme` respetados (tema "Sistema" por defecto).

## 6. Marca

- **Nombre**: siempre **carli**, en minúscula, también al empezar frase ("carli está bloqueada"). En el wordmark va en la fuente del sistema, peso 650, tracking −0.03em.
- **Logo**: una carita mínima, un cuadrado redondeado con dos ojos ovalados. Se dibuja en una caja de 100 × 100: cara `x/y 12–88` con radio 28; ojos en `(39, 47)` y `(61, 47)`, radios 5,5 × 9. Cara ember (`#E5063F`) y ojos blancos en ambos temas. Sin sombras, degradados ni boca.
- **Personalidad**: cercana y simpática. La carita puede expresar estados (parpadear, pensar) cuando llegue la IA; sin más rasgos que los ojos.
- **Firma**: logo a la izquierda del nombre, separados 10 px, logo ≈ 1,4 × la altura de la x (28 px con texto de 18 px en la sidebar, 36 px con 20 px en el login).
- **Iconos de app**: la geometría vive en `frontend/scripts/lib/carli-mark.mjs` y `npm run icons` genera todo con ella.
  - `icon.svg`, `icon-*.png`, `favicon-32.png`: la carita sola, ember con ojos blancos, sin fondo.
  - `maskable-*.png`: fondo negro y carita ember al 56 % (dentro de la zona segura).
  - `apple-touch-icon.png` y el `AppIcon` de iOS: fondo negro y carita ember al 62 %.
- **Arranque**:
  - La pantalla de lanzamiento nativa (iOS y PWA) es la carita de 96 pt centrada sobre `--bg`, en claro y oscuro (`npm run splash`).
  - La web arranca con ese mismo fotograma (`#launch` en `index.html`), así que no hay salto.
  - En la app instalada y en el navegador la carita parpadea dos veces y aparece "carli" debajo; dura 1,5 s, se salta al tocar y se funde en 240 ms. La anima y la cierra `core/launch/launch-screen.ts` tras la primera navegación y, si el bloqueo con Face ID está activo, después de desbloquear: mientras se pide Face ID la carita queda quieta, y si falla se muestra directamente la pantalla de bloqueo.
  - Con `prefers-reduced-motion` no hay animación y se cierra en cuanto la app está lista (los e2e lo activan para no esperar).
