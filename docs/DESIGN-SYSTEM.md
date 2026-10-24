# Design System · "Base"

Design system propio de Personal App, **inspirado en la estética de la app de ChatGPT**: monocromo, mucho aire, sin sombras, controles en forma de píldora y el color reservado para los datos y los estados. Se implementa en `frontend/src/app/ui/` como componentes Angular standalone, con tokens en CSS custom properties y Tailwind CSS v4 (`@theme`) como capa de utilidades. El [mockup](../mockup/index.html) usa exactamente estos tokens y tiene una página "Design system" con el catálogo.

> Es una inspiración de estilo, no una copia: no se usan su tipografía (Söhne es de pago), su logo ni sus assets.

## 1. Principios

1. **Monocromo por defecto.** Negro, blanco y grises. La acción principal es negra en claro y blanca en oscuro. Nada de color de marca.
2. **El color significa algo.** Solo aparece en gráficos (identidad de categoría), en ingresos (verde) y en estados (aviso ámbar, excedido rojo). Un gasto normal se muestra en color de texto.
3. **Plano.** Sin sombras en tarjetas; se separan por un borde fino o por el fondo. Sombra solo en lo que flota (diálogos, menús, toasts).
4. **Redondeado y táctil.** Botones, chips, buscador y segmentados en píldora. Objetivos táctiles ≥ 44 px.
5. **Números primero.** Cifras grandes con dígitos tabulares, peso 600, tracking ligeramente negativo.
6. **Claro y oscuro de primera.** El oscuro usa grises cálidos neutros (`#212121`), no negro puro.

## 2. Tokens

### 2.1 Superficies y texto

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `--bg` | `#FFFFFF` | `#212121` | Fondo de la app y de las tarjetas |
| `--surface` | `#FFFFFF` | `#212121` | Tarjetas (diferenciadas por borde) |
| `--surface-2` | `#F4F4F4` | `#2F2F2F` | Hover, buscador, iconos, segmentado |
| `--sidebar` | `#F9F9F9` | `#181818` | Barra lateral |
| `--border` | `#E5E5E5` | `#383838` | Bordes y divisores |
| `--text` | `#0D0D0D` | `#ECECEC` | Texto principal |
| `--text-2` | `#5D5D5D` | `#B4B4B4` | Texto secundario |
| `--text-3` | `#767676` | `#8F8F8F` | Ayudas, placeholders, ejes |

### 2.2 Acción y estados

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `--primary` | `#0D0D0D` | `#FFFFFF` | Botón principal, chip activo, FAB, barras de progreso OK |
| `--primary-hover` | `#333333` | `#DADADA` | |
| `--primary-soft` | `#ECECEC` | `#2F2F2F` | Ítem de navegación activo, selección |
| `--on-primary` | `#FFFFFF` | `#0D0D0D` | Texto sobre primario |
| `--positive` | `#0F7B4A` | `#4ADE80` | Ingresos, variación favorable |
| `--warning` | `#B45309` | `#FBBF24` | Presupuesto 80–100 %, pendientes |
| `--negative` | `#D92D20` | `#F87171` | Excedido, errores, borrar |
| `--*-soft` | ver mockup | ver mockup | Fondos de badges de estado |
| `--focus-ring` | `rgba(13,13,13,.18)` | `rgba(255,255,255,.25)` | Anillo de foco 3 px |

Los estados siempre van con icono o texto, nunca solo color.

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

- Familia: pila del sistema `ui-sans-serif, -apple-system, system-ui, "Segoe UI", Helvetica, Arial, sans-serif` (SF Pro en Apple, Segoe UI en Windows). Alternativa web consistente entre plataformas: **Inter**.
- Números: `font-variant-numeric: tabular-nums` en importes, tablas y KPI.

| Token | Tamaño / línea | Peso | Uso |
|---|---|---|---|
| `display` | 36/42 · tracking −0.02em | 600 | Cifra héroe (patrimonio, importe en alta) |
| `h1` | 22/30 · −0.01em | 600 | Título de página |
| `h2` | 16/24 | 600 | Título de tarjeta/sección |
| `body` | 15/22 | 400 | Texto general |
| `body-strong` | 15/22 | 500 | Importes en listas, navegación activa |
| `small` | 13/18 | 400 | Secundario |
| `caption` | 12/16 | 500 | Ejes, badges, etiquetas de sección (sin mayúsculas) |

### 2.5 Forma, sombras y movimiento

- Radios: `--r-sm 8px` (badges cuadrados, tooltips), `--r-md 12px` (inputs, filas), `--r-lg 20px` (tarjetas), `--r-xl 28px` (sheets móviles, diálogos), `--r-full 999px` (botones, chips, buscador, segmentado, iconos, FAB, toast).
- Iconos: Hugeicons (`@hugeicons/core-free-icons`, estilo stroke rounded), trazo 1.5, 18 px. Los nombres que usa la app (y que guarda la base de datos) siguen la nomenclatura kebab-case de siempre (`shopping-cart`, `piggy-bank`…) y se traducen al glifo de Hugeicons en `ui/icon/icon-set.ts` y `finance-icons.ts`; para añadir uno, se registra ahí con su equivalente.
- Sombras: ninguna en tarjetas. `--shadow-2` solo para diálogos, menús y FAB.
- Espaciado (px): `2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64`.
- Movimiento: `120ms` hover, `200ms ease-out` entrada de diálogos y sheets; respetar `prefers-reduced-motion`.

### 2.6 Layout y breakpoints

| Nombre | Ancho | Layout |
|---|---|---|
| `sm` | < 640 | Bottom nav (5 ítems) + FAB redondo negro, 1 columna, gutter 16 px; diálogos como sheet inferior |
| `md` | 640–1023 | Bottom nav, 2 columnas en dashboard |
| `lg` | ≥ 1024 | Sidebar 260 px gris claro sin borde, contenido máx. 1160 px, gutter 32 px |

## 3. Componentes (`ui/`)

| Componente | Notas de estilo |
|---|---|
| `ui-button` | `primary` (negro/blanco), `secondary` (borde), `ghost`, `danger`; píldora; `sm/md/lg`; `icon-only` circular; estado `loading` |
| `ui-input`, `ui-textarea` | Borde fino, radio 12, foco oscureciendo el borde (sin halo de color) |
| `ui-search` | Píldora rellena `--surface-2` sin borde, icono a la izquierda (estilo "composer") |
| `ui-money-input` | Cifra display centrada, `inputmode="decimal"`, coma decimal, devuelve céntimos |
| `ui-select`, `ui-combobox` | CDK Overlay + Listbox; menú con `--shadow-2` y radio 16 |
| `ui-category-picker` | Cuadrícula de iconos circulares; el seleccionado se invierte (fondo `--primary`) |
| `ui-date-picker` | Chips "Hoy", "Ayer"; semana empieza en lunes |
| `ui-segmented` | Píldora `--surface-2`; opción activa con fondo `--bg` y sombra mínima |
| `ui-chip` | Píldora con borde; activo = relleno `--primary` |
| `ui-card` | Borde 1 px, radio 20, sin sombra |
| `ui-stat` | Etiqueta pequeña, valor 24/600, variación con icono + texto |
| `ui-progress` | 8 px; OK = `--text`, aviso = `--warning`, excedido = `--negative` (+ icono y texto) |
| `ui-badge` | neutral, positive, warning, negative |
| `ui-list-item` | Icono circular monocromo, título, subtítulo, valor a la derecha; hover `--surface-2` |
| `ui-dialog` / `ui-sheet` | Mismo contenido; sheet inferior en móvil con radio 28 |
| `ui-toast` | Píldora invertida (`--text` de fondo) con acción "Deshacer" |
| `ui-tooltip` | Invertido, radio 8 |
| `ui-tabs` | Subrayado negro/blanco |
| `ui-empty-state`, `ui-skeleton`, `ui-avatar` | Monocromos |
| `ui-chart` | Wrapper Chart.js; único sitio con paleta categórica; leyenda, tooltip y vista tabla |
| `ui-nav-*` | sidebar, bottom-nav, topbar; ítem activo = fondo `--primary-soft`, sin color |

## 4. Patrones de contenido

- **Importes**: `1.234,56 €` (es-ES con `useGrouping: 'always'`). Gastos con `−` en color de texto; ingresos con `+` en `--positive`; transferencias en `--text-2` sin signo.
- **Fechas**: cabeceras "Hoy", "Ayer", "Jueves 22 oct"; formularios `dd/mm/aaaa`.
- **Tono**: segunda persona, frases cortas. "Te quedan 120 € en Ocio".
- **Vacíos**: explicar la sección y ofrecer la primera acción.
- **Destructivo**: confirmar solo si no se puede deshacer; si se puede, borrar y ofrecer "Deshacer".

## 5. Accesibilidad

- Contraste AA en texto (4,5:1) y componentes (3:1) en ambos temas. `--text-3` está ajustado a `#767676` en claro (4,5:1 sobre blanco); no aclararlo más.
- Foco visible siempre, orden lógico, `Esc` cierra diálogos, `cdkTrapFocus`.
- Gráficos con leyenda, tooltip y alternativa en tabla.
- `prefers-reduced-motion` y `prefers-color-scheme` respetados (tema "Sistema" por defecto).
