# Design System · "Ember"

Design system propio de **carli**, el asistente personal. Desde el 26/10/2026 sigue el prototipo "Health Tracker" que Juanda dejó en `docs/Health Tracker.zip` (tokens en `ds/colors_and_type.css`, derivados del Yurest Design System): estética tipo Apple Fitness, fondo negro puro en oscuro y gris claro en claro, tarjetas grandes y redondeadas, títulos muy gruesos, etiquetas de sección en mayúsculas y un único acento rosa-rojo ("ember"). Sustituye a la dirección "Sol".

Se implementa en la app Flutter: tokens en `app/lib/core/theme/tokens.dart` (`CarliColors` como `ThemeExtension`, `CarliSpace`, `CarliRadius`, `CarliMotion`), tipografía en `typography.dart` (`CarliType`), `ThemeData` claro y oscuro en `theme.dart`, y los componentes en `app/lib/ui/` como widgets `Carli*`. Los colores se leen con `context.colors`. En debug, `/dev/catalogo` muestra todos los componentes. El [mockup](../mockup/index.html) todavía usa los tokens monocromos antiguos.

## 1. Principios

1. **Neutros y un solo acento.** Negro, blanco y grises neutros, más el acento ember. El acento marca la acción principal (botón primario, botón "+" flotante), la pestaña activa, la selección, los enlaces de texto ("Ver", "Ver tabla") y el logo. Como mucho una mancha grande de acento por pantalla (la acción principal).
2. **Chrome neutro.** Barras de navegación, cabeceras, listas, badges y avisos en bloque van en neutros. Excepciones: el punto de notificaciones sin leer (`UnreadDot`, relleno `primary`) y el contador de Pendientes de la pestaña Más (relleno `warning`).
3. **El color significa algo, y poco.** Fuera del acento, el color solo aparece en gráficos (identidad de categoría), en ingresos (verde) y en estados (aviso ámbar, excedido rojo). Los estados colorean el **número**, nunca la barra o el gráfico que lo acompaña. Un gasto normal se muestra en color de texto. El acento y el rojo de "excedido" son parecidos: un estado de error **siempre** lleva icono y texto, nunca solo color.
4. **Plano.** Las tarjetas se separan por el fondo y un borde de 1 px, sin sombra. Sombra (o elevación) solo en lo que flota: botón "+", menús y toasts.
5. **Redondeado y táctil.** Tarjetas de 22 pt, botones y controles de 12 pt (16 pt el grande), avatares y botón "+" redondos. Objetivos táctiles ≥ 44 pt.
6. **Números primero.** Cifras grandes en Geist con dígitos tabulares, peso 600, tracking negativo; la unidad va pequeña y en gris al lado ("78.3 kg", "1.284,50 €").
7. **Claro y oscuro de primera.** El oscuro es negro puro (`#000`) con tarjetas `#161616`; el claro es gris `#F5F5F7` con tarjetas blancas.
8. **Nativo de iOS.** Navegación, títulos grandes, sheets, diálogos de confirmación, switch, segmentado, selector de hora y pull-to-refresh usan los widgets Cupertino con los tokens Ember. Sin efecto ripple de Material (`NoSplash`): la pulsación se marca con opacidad (`Pressable`).

## 2. Tokens

### 2.1 Superficies y texto

`CarliColors.light` / `CarliColors.dark`:

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `bg` | `#F5F5F7` | `#000000` | Fondo de la app y de las barras de navegación (translúcido) |
| `surface` | `#FFFFFF` | `#161616` | Tarjetas, sheets, inputs, tab bar (translúcida) |
| `surface2` | `#F0F0F2` | `#1F1F1F` | Buscador, segmentado, botón ghost, iconos circulares, skeleton, avisos en bloque |
| `sidebar` | `#FFFFFF` | `#0A0A0A` | Sin uso; se conserva por compatibilidad |
| `border` | `#EBEBEB` | `#262626` | Bordes y divisores |
| `text` | `#1F1F1F` | `#FFFFFF` | Texto principal |
| `text2` | `#666666` | `#A3A3A3` | Texto secundario |
| `text3` | `#6E6E6E` | `#8A8A8A` | Ayudas, placeholders, ejes, etiquetas de sección, pestañas inactivas |

### 2.2 Acción y estados

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `primary` | `#E5063F` | `#E5063F` | Ember: botón principal, chip activo, botón "+", selección, switch activo, logo, punto de no leídas |
| `primaryHover` | `#D90033` | `#FA114F` | |
| `primarySoft` | `#FFEBF0` | `#3A0A18` | Badge `primary` |
| `onPrimary` | `#FFFFFF` | `#FFFFFF` | Texto e iconos sobre primario y sobre `dangerFill` |
| `primaryStrong` | `#E5063F` | `#FA114F` | Barras de progreso de objetivos y deudas, trazos de gráfico del acento |
| `brandInk` | `#D90033` | `#FF5C85` | Texto en color de acento (pestaña activa, "Ver tabla", check del select, acciones de la barra de navegación); AA sobre `bg` y `surface` |
| `positive` | `#0F7B4A` | `#10B981` | Ingresos, variación favorable |
| `warning` | `#B45309` | `#F59E0B` | Presupuesto 80–100 %, contador de Pendientes |
| `negative` | `#C8281C` | `#ED5A46` | Texto de excedido, errores de formulario, borde de campo inválido |
| `positiveSoft` · `warningSoft` · `negativeSoft` | `#ECFDF0` · `#FFFBEB` · `#FEF3F2` | `#0F2E22` · `#3A2A0A` · `#3D1A16` | Fondos de badges de estado |
| `focusRing` | `#E5063F` al 25 % | `#FF5C85` al 40 % | Reservado para foco visible (teclado externo) |
| `CarliColors.dangerFill` | `#C8281C` | `#C8281C` | Rellenos destructivos con texto blanco: botón `danger`, fondo del deslizar para borrar |

El ember del prototipo es `#FA114F`, pero con texto blanco da 4,0:1 y no pasa AA; por eso el relleno es `#E5063F` (4,7:1) y `#FA114F` queda para trazos en oscuro. Del mismo modo, el `negative` oscuro (`#ED5A46`) es para texto sobre negro y no aguanta texto blanco encima: los rellenos destructivos usan siempre `dangerFill`, igual en ambos temas. Los estados siempre van con icono o texto, nunca solo color.

### 2.3 Datos y categorías

Paleta categórica de 8 colores (`CarliColors.chart`) en **orden fijo**, validada para daltonismo en pares adyacentes en ambos temas. Se usa **solo en gráficos y leyendas**; en listas los iconos de categoría son monocromos (círculo `surface2` + glifo `text`). El color sigue a la categoría, no a su posición en un ranking; a partir de la 9.ª categoría se agrupa en "Otros".

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

- Familia: **Geist** variable, empaquetada en `app/assets/fonts/Geist-Variable.ttf` (licencia OFL) y declarada en `pubspec.yaml`. `CarliType` fija el peso también como `FontVariation` para que el eje variable lo respete. El prototipo declara "Open Sauce One" para el cuerpo, pero nunca llega a cargarse, así que se usa Geist para todo.
- Números: `CarliType.money(style)` añade `FontFeature.tabularFigures()`; `display` ya la lleva. Se usa en importes, tablas y KPI.

| `CarliType` | Tamaño / línea | Peso | Uso |
|---|---|---|---|
| `display` | 36/42 · tracking −0.02em | 600 | Cifra héroe (patrimonio, importe en alta) |
| `h1` | 28/34 · −0.025em | 800 | Título grande de página ("Hola, Juanda") |
| `h2` | 16/24 | 600 | Título de tarjeta, título de barra compacta |
| `body` | 15/22 | 400 | Texto general |
| `bodyStrong` | 15/22 | 600 | Importes en listas, botones |
| `small` | 13/18 | 400 | Secundario |
| `caption` | 12/16 | 500 | Ejes, badges, etiquetas de campo |
| `eyebrow` | 12/16 · +0.08em · MAYÚSCULAS | 600 | Etiquetas de sección (`CarliSection`: "PRESUPUESTOS", "ESTA SEMANA"), en `text3` |

### 2.5 Forma, sombras y movimiento

- Radios (`CarliRadius`): `sm 6` (tags, skeleton), `md 12` (inputs, filas, select), `control 12` (botones, segmentado, buscador), `controlLg 16` (botón grande), `chip 8` (chips, tooltips de gráfico), `lg 22` (tarjetas), `sheet 28` (sheets inferiores), `xl 32`, `full 999` (avatares, iconos circulares, botón "+", badges, toast).
- Iconos: Hugeicons (`hugeicons`, estilo stroke rounded) con `CarliIcon`, trazo 1.5 (2 en estados activos y badges), 20 pt por defecto. Los nombres que guarda la base de datos siguen la nomenclatura kebab-case de siempre (`shopping-cart`, `piggy-bank`…) y se traducen al glifo con `carliIconNamed()` en `ui/icon_names.dart`, que se mantiene a mano y es la fuente de verdad: para añadir uno, se añade una entrada que asocia el nombre a un glifo de `HugeIconsStrokeRounded`.
- Sombras: ninguna en tarjetas (`elevation: 0`). Solo el botón "+" lleva elevación; sheets y toasts se distinguen por superficie y forma.
- Espaciado (`CarliSpace`, pt): `s2, s4, s8, s12, s16, s20, s24, s32, s40, s48, s64`.
- Movimiento (`CarliMotion`): `hover 120ms`, `enter 200ms` (ease-out; barras de progreso, entradas), `fade 240ms` (salida del arranque). Con "Reducir movimiento" (`MediaQuery.disableAnimationsOf`) no hay animación en progreso, skeleton ni arranque.

### 2.6 Layout

Solo iPhone, una columna, gutter 16 pt.

- **Tab bar** (`CarliBottomNav`) de 5 pestañas: Inicio, Resumen, Movimientos, Presupuestos, Más. `surface` al 82 % con desenfoque y borde superior; ítem activo en `brandInk` con trazo 2, inactivos en `text3`. La pestaña Más lleva el contador de Pendientes.
- **Botón "+"** flotante redondo en `primary` sobre la tab bar: nuevo movimiento desde cualquier pestaña.
- **Páginas** (`CarliPage`): `CupertinoSliverNavigationBar` con título grande `h1` que se compacta a `h2`; fondo `bg` al 85 % y borde inferior de 0,5 pt; pull-to-refresh nativo.
- Altas y edición en sheets inferiores (`showCarliSheet`) o a altura completa (`showFullSheet` con `FullSheetHeader`: "Cancelar" a la izquierda, título y "Guardar" a la derecha).

## 3. Componentes (`app/lib/ui/`)

| Componente | Notas de estilo |
|---|---|
| `CarliButton` | `primary` (ember con texto blanco), `secondary` (borde), `ghost` (relleno `surface2`), `danger` (`dangerFill`); `sm 36` / `md 44` / `lg 52` pt; radio 12 (16 en `lg`); a todo el ancho por defecto (`block`); `CarliButton.icon` circular con `semanticLabel` obligatorio; estado `loading` con `CupertinoActivityIndicator`; deshabilitado al 40 % |
| `CarliInput`, `CarliField` | Relleno `surface`, borde fino, radio 12, foco oscureciendo el borde a `text` (sin halo de color); `CarliField` añade etiqueta `caption`, ayuda y error en `negative` |
| `CarliSearchField` | Radio 12 relleno `surface2` sin borde, icono a la izquierda y botón de borrar |
| `CarliMoneyInput` | Apariencia `display` (cifra grande centrada) o `field`; teclado decimal, coma decimal, signo opcional; devuelve céntimos |
| `CarliSelect` | Campo con chevron que abre un sheet con la lista de `CarliOption`; la opción elegida lleva check en `brandInk` |
| `CarliCategoryPicker` | Cuadrícula de iconos circulares; el seleccionado se invierte (fondo `primary`, glifo `onPrimary`) |
| `CarliDatePicker` | Chips "Hoy", "Ayer" y un tercero con calendario para otra fecha (`dd/mm/aaaa`) |
| `CarliSegmented` | `CupertinoSlidingSegmentedControl` sobre `surface2`; opción activa blanca con texto oscuro en ambos temas |
| `CarliChip` | Radio 8 con borde; activo = relleno `primary` |
| `CarliCard` | `surface` sobre `bg`, borde 1 px, radio 22, sin sombra; pulsable opcional |
| `CarliStat` | Etiqueta pequeña, valor 24/600 tabular, variación con icono + texto; el tono (`CarliTone`) colorea solo la cifra |
| `CarliProgress` + `CarliProgressFigure` | Barra de 8 pt sobre `surface2`. La barra nunca cambia de color por estado: `text` en presupuestos y `primaryStrong` en objetivos y deudas. El aviso (80–100 %) y el exceso se marcan en la **cifra** ("141 / 150 €") con `warning` o `negative`, icono y peso 600 |
| `CarliBadge` | Píldora `caption`; tonos neutral (por defecto), primary, positive, warning, negative. Los avisos de estado (pendiente, por revisar, % de presupuesto, consentimiento de banco) van en **neutral** con icono; el color de estado se reserva para la cifra. Los avisos en bloque (sin categoría, banco) usan `surface2` con texto `text2` |
| `CarliListItem` | Icono circular monocromo, título, subtítulo, valor a la derecha |
| `CarliAmount` | Importe con signo y color según tipo (§4) |
| `showCarliSheet` / `showFullSheet` / `confirmCarli` | Sheet inferior con radio 28 y asa; sheet a altura completa para formularios; confirmación con `CupertinoAlertDialog` (acción destructiva en rojo del sistema) |
| `ToastHost` / `ToastController` | Píldora invertida (fondo `text`, texto `surface`; `negative` en errores) sobre la tab bar, 5 s, con acción "Deshacer" |
| `CarliTabs` | Subrayado de 2 pt en `text` |
| `CarliSwitch` | `CupertinoSwitch` con pista activa `primary` |
| `CarliEmptyState`, `CarliSkeleton`, `CarliAvatar`, `PlaceholderView` | Monocromos sobre `surface2` |
| `AsyncView` | Pinta un `AsyncValue`: el widget de carga que recibe (normalmente skeletons), un `CarliEmptyState` de error con "Reintentar" o los datos |
| `CarliLogo` / `CarliFacePainter` | La carita de carli en `primary` con ojos `onPrimary`; `size` en pt (30 por defecto) y `eyeOpenness` para el parpadeo |
| `CarliChart` | Wrapper de fl_chart (`bar`, `line`, `donut`); único sitio con paleta categórica; leyenda, tooltip invertido y conmutador "Ver tabla" / "Ver gráfico" en `brandInk` |
| `CarliPage`, `CarliSection` | Página con título grande (§2.6) y sección con etiqueta `eyebrow` |
| `Pressable` | Respuesta táctil por opacidad (0,6) para todo lo pulsable |
| `CarliIcon` | Glifo Hugeicons con tamaño, color y trazo |

Fuera de `ui/`: `UnreadDot` y `NotificationsBellButton` (`shell/notifications/`), `PendingBadge` (`shell/pending/`) y los widgets propios de Finanzas en `modules/finance/ui/` (`TransactionRow`, `BudgetLine`, `PeriodSelector`, `UncategorizedNotice`, tarjeta de Inicio).

## 4. Patrones de contenido

- **Importes**: `1.234,56 €` con `formatMoney` (separador de miles siempre, espacio duro antes de `€`, menos tipográfico `−`). Gastos con `−` en color de texto; ingresos con `+` en `positive`; transferencias en `text2` sin signo.
- **Fechas**: cabeceras "Hoy", "Ayer", "Jueves 22 oct"; formularios `dd/mm/aaaa`.
- **Tono**: segunda persona, frases cortas. "Te quedan 120 € en Ocio".
- **Vacíos**: explicar la sección y ofrecer la primera acción.
- **Destructivo**: confirmar solo si no se puede deshacer; si se puede, borrar y ofrecer "Deshacer". En listas, deslizar a la izquierda sobre fondo `dangerFill`.

## 5. Accesibilidad

- Contraste AA en texto (4,5:1) y componentes (3:1) en ambos temas. `text3` está ajustado a `#6E6E6E` en claro (el `#8F8F8F` del prototipo da 3,2:1 y no pasa); no aclararlo más. Texto en color de acento siempre con `brandInk`, nunca con `primary`. Rellenos destructivos con `dangerFill`, nunca con `negative`.
- VoiceOver: los widgets de `ui/` exponen `Semantics` (botones icon-only con `semanticLabel`, progreso con porcentaje y estado, cifras con su lectura completa, contadores en el nombre de la pestaña: "Más, 3 pendientes").
- Gráficos con leyenda, tooltip y alternativa en tabla.
- "Reducir movimiento" y el tema del sistema respetados (tema "Sistema" por defecto; preferencia guardada en `shared_preferences` y sincronizada con el perfil).

## 6. Marca

- **Nombre**: siempre **carli**, en minúscula, también al empezar frase ("carli está bloqueada"). En el wordmark va en Geist, peso 650, tracking −0.03em.
- **Logo**: una carita mínima, un cuadrado redondeado con dos ojos ovalados. Se dibuja en una caja de 100 × 100: cara `x/y 12–88` con radio 28; ojos en `(39, 47)` y `(61, 47)`, radios 5,5 × 9. Cara ember (`#E5063F`) y ojos blancos en ambos temas. Sin sombras, degradados ni boca. En la app lo pinta `CarliFacePainter`.
- **Personalidad**: cercana y simpática. La carita puede expresar estados (parpadear, pensar) cuando llegue la IA; sin más rasgos que los ojos.
- **Firma**: logo a la izquierda del nombre, separados 10 pt, logo ≈ 1,4 × la altura de la x (36 pt con texto de 20 pt en el login).
- **Icono de app**: la geometría vive en `app/tool/lib/carli-mark.mjs`; `node app/tool/generate-ios-assets.mjs` genera el `AppIcon` de iOS (fondo negro y carita ember al 62 %) y la imagen de lanzamiento.
- **Arranque**:
  - La pantalla de lanzamiento nativa (`LaunchScreen.storyboard`) es la carita de 96 pt centrada sobre `bg`, en claro y oscuro.
  - `LaunchOverlay` arranca con ese mismo fotograma, así que no hay salto: la carita parpadea dos veces y aparece "carli" debajo; dura 1,5 s, se salta al tocar y se funde en 240 ms. Si el bloqueo con Face ID está activo, la carita queda quieta mientras se pide Face ID y, si falla, se muestra directamente la pantalla de bloqueo (círculo `primary` con el glifo de Face ID y "carli está bloqueada").
  - Con "Reducir movimiento" no hay animación y se cierra en cuanto la app está lista.
