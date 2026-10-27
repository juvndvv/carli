# PRD · Personal App (shell modular + módulos Finanzas, Tareas, Notas y Hábitos)

| | |
|---|---|
| Autor | Juanda |
| Estado | Borrador v0.1 |
| Fecha | 2026-10-24 |
| Documentos relacionados | [TRD.md](./TRD.md) · [DESIGN-SYSTEM.md](./DESIGN-SYSTEM.md) · [Mockup](../mockup/index.html) |

---

## 1. Visión

Una única app personal, privada y autoalojada, que agrupa distintas áreas de la vida (finanzas, tareas, salud, hábitos, notas) bajo un mismo shell, con un mismo login, un mismo design system y una navegación común. Cada área es un **módulo** independiente que se puede activar o desactivar.

El primer módulo es **Finanzas**: registrar manualmente ingresos y gastos, saber en todo momento cuánto dinero hay en cada cuenta, controlar presupuestos, suscripciones, objetivos de ahorro y deudas.

## 2. Problema

- Las apps comerciales (Fintonic, YNAB, Monarch…) o bien leen el banco y comparten datos con terceros, o son de pago, o no permiten combinar finanzas con otras áreas personales.
- Una hoja de cálculo no da notificaciones, ni uso cómodo desde el móvil, ni gráficos al momento.

## 3. Usuario y contexto

- **Un único usuario** (Juanda). No hay registro público. El modelo de datos se asocia siempre a `user_id` para no cerrar la puerta a más usuarios, pero no se diseña UI multiusuario.
- Uso en **escritorio** (revisar, planificar, analizar) y **móvil** como PWA instalada (apuntar un gasto en 5 segundos).
- Idioma: **español**. Moneda: **EUR** únicamente. Formato `1.234,56 €`, fechas `dd/mm/aaaa`, semana empieza en lunes.

## 4. Objetivos y métricas

| Objetivo | Métrica de éxito |
|---|---|
| Registrar un gasto rápido desde el móvil | ≤ 3 toques y < 10 s desde abrir la app |
| Saber el saldo real | Saldo de cada cuenta cuadra con el banco tras conciliar (diferencia 0 €) |
| Controlar gasto mensual | Ver % consumido de cada presupuesto en el dashboard |
| No olvidar suscripciones ni pagos | Notificación push antes de cada cargo recurrente |
| Hábito de uso | Registrar movimientos al menos 5 días/semana durante el primer mes |

## 5. Alcance

### 5.1 Fases

| Fase | Contenido |
|---|---|
| **F0 · Shell** | Login, layout (sidebar/bottom nav), launcher de módulos, ajustes, tema claro/oscuro, PWA instalable, notificaciones push |
| **F1 · Finanzas MVP** | Cuentas, movimientos, transferencias, categorías y etiquetas, dashboard, presupuestos |
| **F2 · Finanzas v1.1** | Recurrentes/suscripciones, objetivos de ahorro, deudas y préstamos, gastos compartidos, exportación CSV |
| **F3 · Sincronización bancaria** | Conexión de Revolut, BBVA y MyInvestor vía Open Banking (Enable Banking), importación automática de movimientos, bandeja "Sin categorizar", aviso de renovación del consentimiento (§7.2, FI-BK) |
| **F4 · Tareas** | Tareas sueltas, listas, plantillas que se repiten (RRULE y "tras completarla"), vistas Hoy y Próximas, vencidas en Pendientes (§8) |
| **F5+** | Otros módulos: Salud, Hábitos, Notas (solo se reserva su hueco en el shell) |

> Recomendación: no empezar F2 hasta usar F1 dos o tres semanas. Lo que eches en falta en el uso real pesa más que este documento.

### 5.2 Fuera de alcance (explícito)

- Importación CSV/Excel.
- Deduplicación o emparejamiento automático entre movimientos manuales e importados del banco (lo resuelve el usuario).
- Iniciación de pagos (PIS): la conexión bancaria es solo de lectura.
- Movimientos pendientes (no contabilizados) del banco.
- Multimoneda, inversiones, cripto.
- Modo offline / sincronización (excepto Notas, §9.5).
- Varios usuarios, cuentas compartidas con otras personas, roles.
- App nativa (iOS/Android); solo PWA.

## 6. Shell de la app (F0)

### 6.1 Requisitos funcionales

| ID | Requisito | Prioridad |
|---|---|---|
| SH-01 | Login con email + contraseña (sesión con cookie). Sin registro público: el usuario se crea por comando. | Must |
| SH-02 | 2FA TOTP opcional activable desde ajustes. | Should |
| SH-03 | Layout: sidebar en escritorio (≥ 1024 px), bottom navigation + botón flotante "+" en móvil. | Must |
| SH-04 | **Launcher de módulos** ("Inicio"): tarjetas por módulo con un resumen (p. ej. "Gastado este mes 1.240 €"). Los módulos no implementados aparecen como "Próximamente" o se ocultan. | Must |
| SH-05 | Cada módulo puede activarse/desactivarse en Ajustes; uno desactivado desaparece de la navegación. | Should |
| SH-06 | Tema claro / oscuro / sistema, persistido por usuario. | Must |
| SH-07 | PWA instalable (manifest, iconos, splash). | Must |
| SH-08 | Notificaciones push web con centro de preferencias por módulo y tipo. | Must |
| SH-09 | Bandeja de notificaciones dentro de la app (campana) con historial. | Should |
| SH-10 | Búsqueda global (Ctrl/⌘ + K) que cada módulo alimenta. | Could |
| SH-11 | Ajustes de perfil: nombre, email, contraseña, sesiones activas, cierre de sesión en otros dispositivos. | Must |
| SH-12 | **Pendientes**: sección general del shell con todo lo que requiere una acción del usuario, aportado por cada módulo (en Finanzas: movimientos sin categoría, recurrentes por confirmar y posibles transferencias entre cuentas propias). Agrupada por módulo y tipo, con acción rápida en línea (p. ej. elegir categoría) sin salir de la lista. Contador en la navegación y tarjeta en Inicio cuando hay elementos. Llega en F2 con los recurrentes por confirmar; F3 añade los movimientos importados sin categoría. | Must |
| SH-13 | Resumen diario por push (20:00) solo si hay pendientes: "Tienes 7 movimientos por categorizar". Uno al día como máximo, nunca uno por elemento ni por sincronización. Configurable en preferencias de notificaciones. | Should |

### 6.2 Contrato de un módulo (visión de producto)

Todo módulo aporta: entrada en la navegación (icono + nombre), tarjeta-resumen para el Inicio, su propia sección de ajustes, tipos de notificación propios y (opcional) resultados para la búsqueda global.

## 7. Módulo Finanzas

### 7.1 Conceptos

- **Cuenta**: dónde está el dinero. Tipos: *Corriente*, *Ahorro*, *Tarjeta de crédito*, *Efectivo*. Tiene saldo inicial, color/icono, y puede archivarse.
- **Movimiento**: ingreso o gasto en una cuenta, con importe, fecha, categoría, etiquetas, concepto, nota y comercio/beneficiario opcional.
- **Transferencia**: movimiento entre dos cuentas propias. No cuenta como gasto ni ingreso. El pago de la tarjeta de crédito es una transferencia Corriente → Tarjeta.
- **Categoría**: jerárquica de 2 niveles (p. ej. *Hogar › Luz*). Tipo gasto o ingreso. Se entrega un set por defecto editable.
- **Etiqueta**: libre y transversal (p. ej. `#vacaciones-2026`).
- **Periodo financiero**: el "mes" de la app. Va **de nómina a nómina**: empieza el día que se registra la nómina y termina el día antes de la siguiente, así que su duración varía (p. ej. 28 oct → 26 nov). Ver §7.5.
- **Presupuesto**: límite por categoría (o grupo de categorías) para cada periodo financiero.
- **Recurrente**: plantilla de movimiento que se repite (nómina, alquiler, Netflix).
- **Objetivo de ahorro**: meta con importe y fecha opcional.
- **Deuda / préstamo**: dinero que debo o me deben, con plan de pagos opcional.
- **Gasto compartido**: un gasto pagado por mí del que parte corresponde a otra persona (contacto), que genera un "me debe".

### 7.2 Requisitos funcionales

#### Cuentas (F1)
| ID | Requisito | Prio |
|---|---|---|
| FI-AC-01 | CRUD de cuentas con nombre, tipo, saldo inicial, fecha de saldo inicial, color e icono. | Must |
| FI-AC-02 | Saldo actual = saldo inicial + suma de movimientos. Visible en lista y detalle. | Must |
| FI-AC-03 | Tarjeta de crédito: límite de crédito, día de corte y día de cargo; muestra "dispuesto" y "disponible". | Should |
| FI-AC-04 | Archivar cuenta (no se borra si tiene movimientos); las archivadas no suman en el patrimonio. | Must |
| FI-AC-05 | **Conciliar**: introducir el saldo real del banco; si difiere, se crea un movimiento de ajuste. | Should |
| FI-AC-06 | Excluir una cuenta del patrimonio total (p. ej. efectivo de otra persona). | Could |

#### Movimientos (F1)
| ID | Requisito | Prio |
|---|---|---|
| FI-TX-01 | Alta rápida: importe (teclado numérico), tipo gasto/ingreso/transferencia, categoría, cuenta (por defecto la última usada), fecha (hoy por defecto). Resto opcional. | Must |
| FI-TX-02 | Campos opcionales: concepto, comercio, etiquetas, nota. | Must |
| FI-TX-03 | Sugerencia de categoría según el comercio/concepto usado antes. | Should |
| FI-TX-04 | Listado agrupado por día, con scroll infinito, totales del periodo y filtros: periodo, cuenta, categoría, etiqueta, tipo, rango de importe, texto. | Must |
| FI-TX-05 | Editar, duplicar y borrar (con deshacer durante 5 s). | Must |
| FI-TX-06 | Edición masiva: cambiar categoría/etiquetas/cuenta de varios movimientos. | Could |
| FI-TX-07 | Dividir un movimiento en varias categorías (split). | Could |
| FI-TX-08 | Estado *pendiente* / *confirmado* (los previstos de recurrentes entran como pendientes). | Should |

#### Categorías y etiquetas (F1)
| ID | Requisito | Prio |
|---|---|---|
| FI-CA-01 | CRUD de categorías de 2 niveles con icono y color; tipo gasto/ingreso. | Must |
| FI-CA-02 | Set por defecto en español (Hogar, Alimentación, Transporte, Ocio, Salud, Suscripciones, Ropa, Educación, Regalos, Impuestos, Otros; ingresos: Nómina, Extra, Reembolsos, Intereses). | Must |
| FI-CA-03 | Borrar categoría con movimientos obliga a reasignarlos. | Must |
| FI-CA-04 | Gestión de etiquetas (renombrar, fusionar, borrar). | Should |

#### Dashboard (F1)
| ID | Requisito | Prio |
|---|---|---|
| FI-DB-01 | Patrimonio neto (suma de cuentas no archivadas, tarjetas restan). | Must |
| FI-DB-02 | Ingresos, gastos y ahorro del periodo en curso vs. periodo anterior. | Must |
| FI-DB-03 | Gasto por categoría del mes (donut / barras). | Must |
| FI-DB-04 | Evolución de 12 meses: ingresos vs gastos (barras) y patrimonio (línea). | Must |
| FI-DB-05 | Estado de presupuestos (top 5 más consumidos). | Must |
| FI-DB-06 | Próximos cargos recurrentes (7 días). | Should (F2) |
| FI-DB-07 | Últimos movimientos (5). | Must |

#### Presupuestos (F1)
| ID | Requisito | Prio |
|---|---|---|
| FI-BU-01 | Presupuesto por periodo financiero y categoría (o categoría padre, que incluye sus hijas). | Must |
| FI-BU-02 | Barra de progreso con estados: OK (< 80 %), aviso (80–100 %), excedido (> 100 %). | Must |
| FI-BU-03 | Proyección a fin de periodo según ritmo de gasto (usando la fecha prevista de la próxima nómina). | Should |
| FI-BU-04 | Arrastre (rollover) opcional del sobrante/exceso al periodo siguiente. | Could |
| FI-BU-05 | Notificación push al cruzar 80 % y 100 %. | Must |
| FI-BU-06 | Al abrirse un periodo nuevo, copiar automáticamente los presupuestos del anterior (editable). | Should |

#### Recurrentes y suscripciones (F2)
| ID | Requisito | Prio |
|---|---|---|
| FI-RE-01 | Plantilla con importe, cuenta, categoría, frecuencia (semanal, mensual, trimestral, anual, cada N días/meses), fecha de inicio y fin opcional. | Must |
| FI-RE-02 | Modo *automático* (se crea confirmado) o *con confirmación* (se crea pendiente y se notifica). | Must |
| FI-RE-03 | Vista "Suscripciones": coste mensual y anual total, próximos cargos, marcar como cancelada. | Must |
| FI-RE-04 | Push X días antes del cargo (configurable, por defecto 2). | Must |
| FI-RE-05 | Detección de importe distinto al previsto al confirmar (aviso de subida de precio). | Could |

#### Objetivos de ahorro (F2)
| ID | Requisito | Prio |
|---|---|---|
| FI-GO-01 | Objetivo con nombre, importe meta, fecha objetivo opcional, icono. | Must |
| FI-GO-02 | Aportaciones manuales o vinculando una cuenta de ahorro (el progreso es su saldo). | Must |
| FI-GO-03 | Aportación mensual necesaria para llegar a tiempo. | Must |
| FI-GO-04 | Push al alcanzar 25/50/75/100 %. | Could |

#### Deudas y préstamos (F2)
| ID | Requisito | Prio |
|---|---|---|
| FI-DE-01 | Registro de deuda con dirección (yo debo / me deben), contraparte, importe, fecha, nota. | Must |
| FI-DE-02 | Pagos parciales vinculados a movimientos; saldo pendiente. | Must |
| FI-DE-03 | Préstamo con cuota (importe fijo, nº de cuotas, día de cargo) que genera un recurrente. Sin cálculo de amortización francesa en v1. | Should |
| FI-DE-04 | Recordatorio push de cobro/pago. | Should |

#### Gastos compartidos (F2)
| ID | Requisito | Prio |
|---|---|---|
| FI-SH-01 | Contactos (solo nombre, sin cuenta de usuario). | Must |
| FI-SH-02 | Al crear un gasto, marcarlo como compartido: a partes iguales, por porcentaje o por importe con uno o varios contactos. | Must |
| FI-SH-03 | La parte ajena no cuenta como gasto propio en dashboard ni presupuestos. | Must |
| FI-SH-04 | Saldo por contacto (me debe / le debo) y "liquidar" registrando el cobro. | Must |

#### Exportación y ajustes (F2)
| ID | Requisito | Prio |
|---|---|---|
| FI-EX-01 | Exportar movimientos filtrados a CSV. | Should |
| FI-EX-02 | Backup completo del módulo en JSON. | Could |
| FI-ST-01 | Ajustes: cuenta por defecto, umbrales de aviso de presupuesto y configuración del periodo financiero (§7.5). | Should |

#### Sincronización bancaria (F3)
Complementa la entrada manual, no la sustituye. Proveedor: Enable Banking (agregador con licencia AISP, modo gratuito para cuentas propias). Bancos: Revolut, BBVA y MyInvestor; se conectan todas las cuentas que exponga la API (tarjetas de crédito incluidas si aparecen). PSD2 solo da acceso a cuentas de pago: de MyInvestor se sincronizan la cuenta remunerada (tipo ahorro) y la tarjeta, **no** fondos, acciones, cartera indexada ni plan de pensiones.

| ID | Requisito | Prio |
|---|---|---|
| FI-BK-01 | Conectar un banco desde Ajustes → Bancos: elegir banco, redirección al banco para autorizar (SCA), volver a la app y **vincular cada cuenta del banco a una cuenta existente** o crear una nueva. La cuenta nueva se llama como en el banco: «BBVA · Cuenta Online», «Revolut · Gastos» (hucha); sin nombre propio, «Revolut · Principal», «· Tarjeta», «· Ahorro» o «· Compartida» si es conjunta. | Must |
| FI-BK-02 | Por cada cuenta vinculada, fecha **"importar desde"** (por defecto, el día de la conexión) para no duplicar el histórico ya apuntado a mano. | Must |
| FI-BK-03 | Sincronización automática varias veces al día (máx. 4, límite PSD2) y botón "Sincronizar ahora". | Must |
| FI-BK-04 | Solo se importan movimientos contabilizados. Entran con concepto, comercio, importe y fecha del banco, **sin categoría**, y marcados con origen "banco" (icono en el listado). | Must |
| FI-BK-05 | Un ingreso o gasto **sin categoría no está terminado**: aparece en Pendientes (SH-12) hasta que se le asigna una, con marca "Por revisar" en el listado y filtro "Sin categoría" en Movimientos. Es un estado calculado (categoría vacía), no un campo aparte. Los movimientos manuales exigen categoría al crearlos, así que en la práctica solo los importados quedan por revisar. | Must |
| FI-BK-06 | Un movimiento importado se puede editar (categoría, etiquetas, notas, compartido) y borrar. Si se borra, **no vuelve** en la siguiente sincronización. | Must |
| FI-BK-07 | Mostrar en cada cuenta vinculada el **saldo que informa el banco** junto al calculado, y la diferencia. "Conciliar" (FI-AC-05) con ese saldo precargado. | Should |
| FI-BK-08 | Estado de cada conexión: activa, caduca en N días, caducada, error. Push **7 días y 1 día antes** de que caduque el consentimiento (90 días en los bancos que van por Redsys, como BBVA y MyInvestor; hasta 180 en otros) y botón "Renovar". | Must |
| FI-BK-09 | Desconectar un banco: revoca el consentimiento; los movimientos ya importados se conservan. | Must |
| FI-BK-10 | Reglas de autocategorización por texto del comercio ("MERCADONA" → Supermercado). Al categorizar un importado, ofrecer "Aplicar a los N parecidos y recordar". Los que casan con una regla entran ya categorizados y no pasan por Pendientes. | Should |
| FI-BK-11 | Mientras haya gastos sin categoría en el periodo, Presupuestos y dashboard muestran **"X € sin categorizar"**, porque ese gasto aún no cuenta en ningún presupuesto. | Must |
| FI-BK-12 | **Detección automática de transferencias** entre cuentas conectadas: al terminar cada sincronización, un gasto importado en una cuenta y un ingreso importado en otra, con el mismo importe y a 3 días o menos, son pareja candidata. Si es el **único** candidato en ambos sentidos y hay al menos una señal fuerte (IBAN de la contraparte = la otra cuenta, contraparte = el titular, concepto de traspaso propio / nombre del otro banco, o movimiento interno entre dos cuentas del mismo banco sin contraparte cuyo concepto nombra la otra cuenta, como «To EUR Gastos»), y ninguno de los dos tiene categoría, se convierten solos en transferencia (no cuentan como gasto ni ingreso). Se marcan como "Detectada" y se pueden **deshacer**: vuelven a gasto e ingreso sin categoría y esa pareja no se vuelve a proponer. Tras "Sincronizar ahora" se avisa de cuántas se han detectado. | Must |
| FI-BK-13 | Las parejas dudosas (solo importe y fecha, varios candidatos o algún movimiento ya categorizado) aparecen en Pendientes como **"¿Es una transferencia entre BBVA y Revolut?"** con *Confirmar* y *No es transferencia* (que se recuerda). Mientras un movimiento esté propuesto como transferencia no aparece además como "sin categoría" en Pendientes. | Must |
| FI-BK-15 | Movimiento a o desde una cuenta que el banco no expone (p. ej. la Cuenta Remunerada de Revolut): si el importado no tiene contraparte importada ni externa y su concepto es «To/From X», donde X es el nombre de **una sola** cuenta manual («Revolut · Cuenta Remunerada»), se enlaza solo con esa cuenta como en FI-BK-14. Deshacer lo devuelve a gasto o ingreso y no se vuelve a enlazar. | Should |
| FI-BK-14 | Transferencia con una cuenta **sin conexión** (p. ej. MyInvestor manual): en el detalle de un gasto o ingreso importado, "Es una transferencia a/desde…" eligiendo una cuenta manual. El importado pasa a ser una pata y se crea la otra en la cuenta manual. Deshacer borra la pata creada. Importe, fecha y cuenta del importado siguen sin poder cambiarse. | Should |
| FI-BK-16 | **Recurrentes en cuentas conectadas**: el previsto entra como pendiente y espera al banco. Al importar, un movimiento de la misma cuenta y tipo a ±5 días de la fecha prevista lo sustituye si el importe coincide exacto, o si el comercio del recurrente aparece en el del banco y el importe difiere un 50 % o menos. Se queda con el comercio y la categoría del recurrente y con importe y fecha del banco. Si el cargo llega antes de generarse el previsto, se enlaza con esa ocurrencia y el recurrente avanza. Si pasan 5 días sin que entre, aparece en Pendientes como «No ha entrado en el banco» y se avisa al día siguiente. | Must |

Notas:
- Sin deduplicación automática: si un gasto se apunta a mano y luego llega del banco, cuenta dos veces hasta que el usuario borre uno. FI-BK-07 hace visible la diferencia.
- Una transferencia entre dos bancos conectados (p. ej. BBVA → Revolut) llega como gasto en una cuenta e ingreso en la otra; se detecta y convierte sola cuando la pareja es clara (FI-BK-12) o se propone en Pendientes (FI-BK-13). Con una cuenta manual se enlaza a mano (FI-BK-14).
- Un ingreso importado no abre periodo (§7.5) hasta que el usuario le asigna la categoría Nómina.

### 7.3 Flujos principales

1. **Apuntar gasto en móvil**: abrir PWA → "+" → teclear importe → elegir categoría (cuadrícula de recientes) → Guardar. Cuenta y fecha por defecto.
2. **Revisión de pendientes**: aviso diario o contador → Pendientes → confirmar o descartar posibles transferencias → elegir categoría en línea (y "aplicar a parecidos") → confirmar recurrentes → Conciliar cuentas.
3. **Planificar el mes**: Presupuestos → "Copiar del mes anterior" → ajustar importes.
4. **Recibir aviso de suscripción**: push "Netflix 13,99 € pasado mañana" → abrir → confirmar o cancelar suscripción.
5. **Cena compartida**: gasto 80 € → "Compartir" → Ana 50 % → saldo Ana: te debe 40 €.

### 7.4 Notificaciones del módulo

| Tipo | Disparador | Por defecto |
|---|---|---|
| Presupuesto al 80 % / 100 % | Al guardar un movimiento que cruza el umbral | On |
| Cargo recurrente próximo | X días antes, a las 09:00 | On |
| Recurrente pendiente de confirmar | Día del cargo, 09:00; en cuentas conectadas, 6 días después si no ha entrado | On |
| Objetivo alcanzado | Al cruzar hitos | Off |
| Recordatorio de deuda | Fecha de vencimiento | On |
| Resumen semanal | Lunes 09:00 | Off |
| Pendientes por revisar (SH-13) | Diario 20:00, solo si hay pendientes | On |

### 7.5 Periodo financiero (de nómina a nómina)

La nómina no llega siempre el mismo día (festivos, fines de semana, pagas extra), así que el periodo no tiene un día fijo de inicio: **lo abre la propia nómina**.

| ID | Requisito | Prio |
|---|---|---|
| FI-PE-01 | Una o varias categorías de ingreso se marcan como "abre periodo" (por defecto *Nómina*). | Must |
| FI-PE-02 | Al registrar (o confirmar) un ingreso de esa categoría se abre un periodo nuevo que empieza en la fecha de ese ingreso; el anterior se cierra el día antes. | Must |
| FI-PE-03 | Para no partir el periodo por una paga extra o un segundo ingreso, solo se abre periodo si han pasado al menos **N días** desde el inicio del actual (por defecto 20, configurable). Si no, el ingreso cuenta dentro del periodo actual. | Must |
| FI-PE-04 | Ajuste manual: el usuario puede mover la fecha de inicio de un periodo o abrir uno a mano (p. ej. si cobra en efectivo o se retrasa la nómina). | Must |
| FI-PE-05 | Si se edita la fecha o se borra la nómina que abrió un periodo, los límites se recalculan y se avisa al usuario. | Should |
| FI-PE-06 | Fin previsto del periodo actual = fecha prevista de la próxima nómina (según su recurrente) o, si no hay, inicio + 1 mes. Se usa para "quedan X días" y proyecciones. | Must |
| FI-PE-07 | Si pasa la fecha prevista y no se ha registrado la nómina, push: "¿Has cobrado ya? Registra la nómina para empezar el nuevo periodo". El periodo sigue abierto hasta entonces. | Should |
| FI-PE-08 | Nombre del periodo por su mes de inicio mayoritario: "Periodo de noviembre (28 oct – 26 nov)". El selector de periodo sustituye al de mes en dashboard, movimientos y presupuestos. | Must |
| FI-PE-09 | Alternativa en ajustes: modo "mes natural" para quien no quiera periodos por nómina. | Could |

Ejemplo: nómina el 28/09 → periodo 28/09–27/10. Nómina el 28/10 → nuevo periodo desde el 28/10. Paga extra el 15/11 (solo 18 días después) → no abre periodo. Nómina el 26/11 (adelantada) → periodo 28/10–25/11 y nuevo desde el 26/11.

## 8. Módulo Tareas

Estado: v1 implementada el 2026-10-26 (detalle técnico en TRD §4.1.3, §5.4, §6.3 y ADR-013). Entran todos los Must y Should salvo TA-06 (avisos a la hora), más TA-07 (Importante), TA-08 (búsqueda, en la búsqueda global), TA-VI-06 (registro de hechas, sin filtros de fecha en la app) y la vista del historial de TA-PL-09. Mockups: https://claude.ai/artifact/QufJbwpf7jxkuNM72bsK63

### 8.1 Conceptos

- **Tarea**: algo que hacer una vez. Título, notas opcionales, fecha opcional (con hora opcional), lista, subtareas opcionales. Estados: *abierta*, *hecha*, *omitida*.
- **Plantilla**: molde de una tarea que se repite ("Sacar la basura", "Pagar comunidad"). Guarda título, notas, lista, subtareas, hora y **frecuencia**. No se completa: genera tareas que sí se completan.
- **Ocurrencia**: cada fecha en la que una plantilla toca. Se convierte en tarea cuando llega su día (o N días antes, si la plantilla lo pide).
- **Lista**: agrupación simple y plana (Casa, Personal, Trabajo…). Una tarea está en una sola lista. Hay una lista por defecto, *Bandeja*, para lo que se apunta sin clasificar.
- **Vencida**: tarea abierta con fecha anterior a hoy. Es un estado calculado, no un campo (mismo criterio que ADR-009).

### 8.2 Frecuencia (el "cron")

No se expone una expresión cron. Internamente se guarda una **regla RRULE (RFC 5545)** + fecha de inicio, porque cron no sabe expresar "cada 2 semanas", "cada 3 días desde el 4 de marzo" ni "el último viernes del mes", y RRULE sí (y hay librerías maduras en PHP y Dart). En la UI, un constructor con estas opciones:

| Tipo | Ejemplo en la UI | RRULE |
|---|---|---|
| Diaria / cada N días | Cada 3 días | `FREQ=DAILY;INTERVAL=3` |
| Semanal en días concretos | Cada lunes y jueves | `FREQ=WEEKLY;BYDAY=MO,TH` |
| Cada N semanas | Cada 2 semanas, el sábado | `FREQ=WEEKLY;INTERVAL=2;BYDAY=SA` |
| Mensual por día | El día 1 de cada mes | `FREQ=MONTHLY;BYMONTHDAY=1` |
| Mensual por posición | El último viernes de cada mes | `FREQ=MONTHLY;BYDAY=FR;BYSETPOS=-1` |
| Último día del mes | Último día de cada mes | `FREQ=MONTHLY;BYMONTHDAY=-1` |
| Anual | Cada 15 de marzo | `FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15` |
| **Tras completarla** | 10 días después de hacerla | sin RRULE: `interval_after_done = 10 días` |

El último tipo no es un calendario: la siguiente fecha se calcula desde el día en que completas la anterior (regar plantas, cambiar sábanas, cortarse el pelo). Es lo que más falla en las apps que solo tienen calendario fijo.

### 8.3 Requisitos funcionales

#### Tareas
| ID | Requisito | Prio |
|---|---|---|
| TA-01 | Alta rápida: título y fecha con atajos (Hoy, Mañana, Fin de semana, Sin fecha). Lista por defecto: Bandeja. ≤ 2 toques tras escribir. | Must |
| TA-02 | Completar con un toque (círculo), con deshacer en toast durante 4 s. | Must |
| TA-03 | Editar título, notas, fecha, hora, lista. Borrar con confirmación. | Must |
| TA-04 | Posponer desde la fila (deslizar): Mañana, Fin de semana, Próxima semana, Elegir fecha. | Must |
| TA-05 | Subtareas como lista de comprobación dentro de la tarea; la tarea no se completa sola al marcarlas todas. | Should |
| TA-06 | Aviso local a la hora indicada, si la tarea tiene hora. **Fuera de la v1** (§8.8). | Should |
| TA-07 | Prioridad: marca única "Importante" (sin niveles). Ordena primero dentro del día. | Could |
| TA-08 | Búsqueda en tareas (alimenta SH-10). | Could |

#### Plantillas
| ID | Requisito | Prio |
|---|---|---|
| TA-PL-01 | Crear plantilla con título, lista, notas, subtareas, hora opcional y frecuencia (§8.2). Desde cero o activando "Repetir" al crear una tarea. | Must |
| TA-PL-02 | Vista previa de las 5 próximas fechas mientras se edita la frecuencia, y descripción en lenguaje natural ("Cada 2 semanas, el sábado"). | Must |
| TA-PL-03 | Inicio y fin: fecha de inicio (por defecto hoy); fin nunca, en una fecha o tras N veces. | Must |
| TA-PL-04 | **Si no la completas** (por plantilla): *Sustituir* (por defecto: al generar la nueva, la anterior abierta pasa a *omitida*) o *Acumular* (se mantienen todas abiertas). Tipo "tras completarla" no aplica: nunca hay dos abiertas. | Must |
| TA-PL-05 | Antelación: la tarea aparece el mismo día (por defecto) o N días antes de su fecha ("Pagar IBI" aparece 7 días antes con fecha de vencimiento). | Should |
| TA-PL-06 | Pausar / reanudar sin perder la configuración. Una pausada no genera ni aparece en Próximas. | Must |
| TA-PL-07 | Saltar una ocurrencia concreta desde Próximas o desde la tarea ("Saltar esta vez"). | Should |
| TA-PL-08 | Editar una plantilla afecta a las ocurrencias futuras. La tarea abierta ya generada pregunta: "¿Aplicar también a la de hoy?". Las hechas no cambian nunca. | Must |
| TA-PL-09 | Historial por plantilla: últimas ocurrencias con hecha / omitida / saltada y racha simple ("8 de las últimas 10"). Se guarda siempre (cada ocurrencia con su estado y fecha) aunque la vista llegue después: es lo que usará el futuro módulo Hábitos. | Must (datos) / Could (vista) |
| TA-PL-10 | Borrar plantilla: las tareas ya generadas se quedan (abiertas o hechas); se ofrece borrar también la abierta. | Must |

#### Vistas
| ID | Requisito | Prio |
|---|---|---|
| TA-VI-01 | **Hoy**: vencidas (arriba, agrupadas) + tareas de hoy + hechas hoy (plegadas al final). Progreso del día "3 de 7". | Must |
| TA-VI-02 | **Próximas**: agenda de 14 días con las tareas con fecha y las ocurrencias programadas de las plantillas (en gris, con icono de repetición), calculadas al vuelo, no guardadas. | Must |
| TA-VI-03 | **Listas**: Bandeja + listas del usuario con contador de abiertas; dentro, tareas con y sin fecha. Crear, renombrar, reordenar, archivar listas. | Must |
| TA-VI-04 | **Plantillas**: todas, con frecuencia en texto, próxima fecha, lista y estado (activa / pausada). | Must |
| TA-VI-05 | Tarjeta en **Inicio**: "3 tareas para hoy · 1 vencida" y las 3 primeras con check en línea. | Must |
| TA-VI-06 | Registro de hechas (filtrable por lista y fechas). | Could |

#### Integración con el shell
| ID | Requisito | Prio |
|---|---|---|
| TA-SH-01 | **Pendientes (SH-12)**: solo las tareas **vencidas** (tipo `overdue_task`), con acción en línea Hecha / Posponer a hoy / Omitir. Las de hoy no entran: Pendientes no debe convertirse en una segunda lista de tareas. | Must |
| TA-SH-02 | **Aviso de las 20:00 (SH-13)**: incluye "Te quedan 2 tareas de hoy" si hay abiertas de hoy, y las vencidas en el recuento general. Sigue siendo un solo aviso al día. | Must |
| TA-SH-03 | Ajustes del módulo: lista por defecto, política por defecto (Sustituir/Acumular), mostrar hechas en Hoy, avisos por hora. | Should |

### 8.4 Generación de tareas (comportamiento)

1. Un job diario (00:05 Europe/Madrid) crea las tareas de las ocurrencias con fecha (menos antelación) ≤ hoy. Clave única `plantilla + fecha de ocurrencia`: idempotente.
2. **Puesta al día**: si el backend estuvo parado (el Mac dormido), al volver se generan las ocurrencias perdidas aplicando la política: con *Sustituir* solo se crea la última y las intermedias quedan como omitidas; con *Acumular* se crean todas.
3. **Generación perezosa**: además del job, al pedir Hoy o Próximas se ejecuta la misma puesta al día para ese usuario. Así el resultado es correcto aunque el scheduler no haya corrido.
4. Tipo "tras completarla": al completar, se calcula la siguiente fecha = fecha de completado + intervalo. Si se omite, cuenta desde el día en que se omite.
5. Una tarea generada guarda copia de título/notas/subtareas (editarla no toca la plantilla) y referencia a la plantilla.

### 8.5 Notificaciones del módulo

> **v1**: solo el resumen de las 20:00. Los avisos a la hora de la tarea y el resumen matinal quedan pendientes (§8.8, punto 5): la hora se guarda y se muestra, pero no avisa.

| Tipo | Disparador | Por defecto |
|---|---|---|
| Tarea con hora | A la hora indicada (aviso local) | On |
| Resumen del día | Dentro del aviso de las 20:00 (SH-13) | On |
| Resumen matinal | 08:30, "Hoy tienes 5 tareas" | Off |

Sin APNs, los avisos con hora son **notificaciones locales** que programa la app: solo se reprograman cuando la app se abre, e iOS limita a 64 pendientes. La app calcula las ocurrencias de las plantillas con la misma RRULE (en Dart) para programar los próximos 7 días. Riesgo asumible para uso personal; si molesta, es el motivo para activar APNs.

### 8.6 Fuera de alcance

Tareas compartidas, avisos por ubicación, sincronización con Calendario/Recordatorios de iOS, lenguaje natural ("mañana a las 9"), widgets y Siri (candidatos a F+1), etiquetas, proyectos con secciones, estimaciones de tiempo, dependencias entre tareas.

### 8.7 Riesgos y críticas

| Tema | Comentario |
|---|---|
| Competir con Recordatorios de iOS | Ya tienes una app de tareas gratis, con Siri, widgets y avisos fiables. Lo que justifica este módulo es: plantillas con políticas que Recordatorios no tiene (sustituir/acumular, tras completarla), y estar junto al resto de carli (Inicio, Pendientes, 20:00). Si a las 3 semanas solo usas tareas sueltas, el módulo sobra. |
| Sobrecarga de vistas | Hoy + Próximas + Listas + Plantillas son 4 pestañas. Plantillas podría vivir dentro de Listas o de Ajustes del módulo. Decidido en §8.8 (punto 4). |
| Avisos locales | Ver §8.5. Una tarea con hora creada en una plantilla no avisa si no abres la app en días. |
| Acumulación | "Acumular" en una plantilla diaria genera montañas de vencidas tras una semana fuera. Por eso el valor por defecto es "Sustituir". |
| Pendientes inflado | Si muchas tareas vencen, Pendientes pierde valor para Finanzas. Mitigación: TA-SH-01 solo vencidas, y agrupadas por módulo. |

### 8.8 Decisiones (Juanda, 2026-10-26)

1. Tipo "tras completarla": **entra en la v1**.
2. Si no la completas: **configurable por plantilla** (Sustituir / Acumular), con valor por defecto en Ajustes del módulo (TA-SH-03).
3. Organización: **listas simples**, sin etiquetas.
4. Pestañas: **Plantillas como pestaña propia** (Inicio · Hoy · Próximas · Listas · Plantillas) y **botón "+" también en Tareas**.
5. Avisos a hora concreta: **TODO, se decide más adelante**. TA-06 y §8.5 quedan fuera de la v1; la hora de una tarea se guarda y se muestra, pero no avisa.
6. Hábitos: **sin marca de hábito en Tareas**. Se deja la puerta abierta con el historial por ocurrencia (TA-PL-09); el módulo Hábitos lo importa al convertir una plantilla (§10.2 B).

## 9. Módulo Notas

Notas de texto, listas reutilizables y la lista de la compra, con carpetas multinivel. Funciona sin conexión (§9.5). Mockups (8 pantallas, claro y oscuro): https://claude.ai/artifact/H8MxjZpXViwzBDX2rLLSKA

### 9.1 Conceptos

Una sola entidad, **nota**, con tres tipos. El tipo se puede cambiar después (texto ↔ lista).

- **Nota de texto**: título opcional + cuerpo en **texto plano**. Enlaces detectados. Sin formato (decidido).
- **Lista**: título + elementos marcables (checklist). Cubre "listas" y "checklists": no hay diferencia útil entre las dos. Ejemplos: maleta de viaje, cosas para la mudanza, películas pendientes.
- **Lista de la compra**: una lista con extras de supermercado: cantidad, sección (Fruta, Lácteos…), sugerencias, "En el carro" abajo, **reposición por producto** y botón **Terminar compra**. Sin relación con Finanzas.
- **Carpeta**: agrupación **multinivel** (carpetas dentro de carpetas) para cualquier tipo de nota (Casa › Reformas › Cocina). Una nota está en una carpeta o en la raíz.

Conceptos de la compra:

- **Reposición** (por producto): cada producto habitual tiene su propia frecuencia: *en cada compra*, *cada N días/semanas desde que lo compraste*, o *sin repetir*. Cuando le toca, vuelve solo a la lista sin marcar. Leche cada semana, papel de cocina cada 3 semanas, aceite cada mes.
- **Terminar compra**: vacía el carro y apunta la fecha de compra de cada producto, que es lo que usa la reposición. No guarda importe ni historial.
- **Reinicio de listas** (no compra): "Empezar de nuevo" desmarca todo. Manual.

### 9.2 Frontera con Tareas

Regla única: **¿tiene fecha y te importa si lo hiciste? → Tarea. ¿Es contenido que consultas, rellenas o reutilizas? → Nota.**

| Caso | Dónde | Por qué |
|---|---|---|
| "Hacer la compra" cada sábado | **Tareas** (plantilla) con enlace a la lista de la compra | Tiene fecha, aparece en Hoy, cuenta en la racha y en Pendientes si vence |
| Lo que hay que comprar | **Notas** (compra) | No tiene fecha; se rellena durante la semana |
| Revisión mensual del coche con 6 pasos | **Tareas** (plantilla con subtareas) | Quieres saber si se hizo cada mes (historial TA-PL-09) |
| Maleta de viaje, que reutilizas en cada viaje | **Notas** (lista) + "Empezar de nuevo" | Sin fecha, sin historial: solo desmarcar |
| Comprar papel de cocina cada 3 semanas | **Notas** (reposición del producto) | No te avisa ni vence: solo reaparece en la lista |
| Ideas, apuntes, datos de la caldera | **Notas** (texto) | Contenido |

Consecuencias de diseño:

1. Las notas **no tienen fecha de vencimiento, ni avisos, ni entran en Pendientes ni en el aviso de las 20:00**. Si algo lo necesita, es una tarea.
2. La reposición de un producto **no genera tareas ni avisos**: el producto reaparece en la lista y ya. Usa intervalos "desde la última compra" (como el tipo "tras completarla" de Tareas), no calendario.
3. **Puente en ambos sentidos** (sin duplicar lógica): una tarea o plantilla puede enlazar una nota ("Hacer la compra" → abre la lista); un elemento de una lista se puede convertir en tarea ("Llamar al fontanero" → Bandeja de Tareas).
4. Las **subtareas de Tareas no se convierten en notas** ni al revés: siguen siendo cosas distintas aunque se parezcan visualmente.

Alternativa descartada: hacer las listas repetibles como plantillas de Tareas. Mete en Hoy y Pendientes cosas que no tienen fecha real (la compra no "vence") y obliga a completar algo para que se reinicie.

### 9.3 Requisitos funcionales

#### Notas (todas)
| ID | Requisito | Prio |
|---|---|---|
| NO-01 | Crear desde "+" eligiendo tipo (Texto, Lista, Compra). Abre directamente el editor con el teclado. | Must |
| NO-02 | Guardado automático (sin botón Guardar). Una nota vacía al salir se descarta. | Must |
| NO-03 | Fijar notas: las fijadas van arriba en la vista Notas y salen en la tarjeta de Inicio. | Must |
| NO-04 | Archivar (sale de la vista principal, se ve en "Archivadas") y borrar con deshacer en toast 4 s. | Must |
| NO-05 | Buscar en título, cuerpo y elementos, sin acentos (Postgres `unaccent` + `tsvector` español). Alimenta SH-10. | Must |
| NO-06 | Filtro por tipo: Todas · Texto · Listas · Compra. Orden: fijadas, luego última edición. | Must |
| NO-11 | **Carpetas multinivel**: crear (también dentro de otra), renombrar, reordenar, mover (con su contenido) y borrar (su contenido sube a la carpeta padre, nunca se borra en cascada). Mover una nota desde la nota o deslizando, con un selector en árbol. La raíz de Notas muestra Fijadas, Carpetas (con contador recursivo) y Recientes; dentro de una carpeta, subcarpetas arriba y notas debajo, con migas de pan en la cabecera. | Must |
| NO-12 | La búsqueda y los filtros por tipo buscan en todas las carpetas y muestran la ruta ("Casa › Reformas") bajo cada resultado. | Must |
| NO-07 | Convertir texto ↔ lista: cada línea pasa a ser un elemento, y al revés. | Should |
| NO-08 | Duplicar nota (útil para listas-plantilla: "Maleta playa" → "Maleta montaña"). | Should |
| NO-09 | Enlazar desde Tareas: una tarea o plantilla puede llevar una nota enlazada; la nota muestra "Enlazada en: Hacer la compra". | Should |
| NO-10 | Papelera 30 días en vez de borrado directo. | Could |

#### Listas
| ID | Requisito | Prio |
|---|---|---|
| NO-LI-01 | Añadir elementos en cadena (Intro crea el siguiente). Marcar con un toque. | Must |
| NO-LI-02 | Reordenar arrastrando; borrar deslizando. | Must |
| NO-LI-03 | Opción por lista: los marcados bajan a "Hechos" (plegado) o se quedan en su sitio tachados. | Should |
| NO-LI-04 | "Empezar de nuevo": desmarca todos los elementos (con confirmación). | Must |
| NO-LI-05 | Reinicio programado de una lista (no compra). | Fuera de v1 |
| NO-LI-06 | Convertir elemento en tarea (va a Bandeja de Tareas, con enlace a la nota). | Should |
| NO-LI-07 | Progreso "4 de 9" en la cabecera y en la fila de la vista Notas. | Must |

#### Lista de la compra
| ID | Requisito | Prio |
|---|---|---|
| NO-CO-01 | Alta rápida con sugerencias de lo que has comprado antes (por frecuencia). Cantidad opcional en texto libre ("2", "1 kg"). | Must |
| NO-CO-02 | Agrupación por sección del súper. La sección se recuerda por producto: la primera vez se asigna por diccionario o a mano, luego se aprende. | Must |
| NO-CO-03 | Al marcar, el producto baja a "En el carro" (plegado). Tocarlo lo devuelve. | Must |
| NO-CO-04 | **Reposición por producto**: frecuencia *En cada compra*, *Cada N días / semanas desde que lo compraste* o *Sin repetir* (por defecto). Cuando toca, el producto vuelve a la lista sin marcar, con su cantidad habitual. | Must |
| NO-CO-05 | Varias listas de compra (Súper, Farmacia, Bricolaje). Una es la principal: la que abre la pestaña Compra. | Should |
| NO-CO-06 | **Terminar compra**: vacía "En el carro" (con deshacer) y recalcula la reposición. Sin importe ni historial. | Must |
| NO-CO-07 | Pantalla siempre encendida mientras la lista está abierta en el súper (opción). | Could |

#### Vistas e integración con el shell
| ID | Requisito | Prio |
|---|---|---|
| NO-VI-01 | **Notas**: búsqueda arriba, filtros por tipo, fijadas en tarjetas, resto en lista con vista previa (2 líneas de texto o "4 de 9"). | Must |
| NO-VI-02 | **Compra**: abre directamente la lista principal, lista para usar en el súper. Selector arriba si hay varias. | Must |
| NO-VI-03 | Tarjeta en **Inicio**: "Compra · 8 por comprar" con los 3 primeros y hasta 2 notas fijadas. | Must |
| NO-SH-01 | Pendientes y aviso de las 20:00: **nada** de Notas. | Must |
| NO-SH-02 | Ajustes de Notas: lista de compra principal, secciones (renombrar, ordenar como tu súper), comportamiento de marcados por defecto | Should |

### 9.4 Navegación

Barra contextual: **Inicio · Notas · Compra** + botón "+".

- Tres pestañas, no cinco como Tareas. Carpetas, Archivadas y Papelera viven dentro de Notas; las listas normales viven en Notas filtradas.
- "Terminar compra" va al final de la lista de Compra, nunca en la barra (para no pulsarlo por error).
- "+" en Notas abre el selector de tipo; "+" en Compra añade un producto (foco en el campo de alta rápida), no crea una nota nueva.

### 9.5 Conectividad (decidido: caché + cola offline)

carli es online-only y el backend vive en un Mac que se duerme. Para Notas:

- **Caché local** (SQLite en el dispositivo) de todas las notas, carpetas y productos: siempre se pueden leer.
- **Cola de cambios offline**: marcar, añadir, editar y terminar compra funcionan sin red y se envían al volver.
- La reposición se calcula también en el cliente (mismas reglas), para que los productos que tocan aparezcan aunque no haya red.
- Conflictos: un solo usuario y un dispositivo; "último en escribir gana" por elemento con `updated_at`.
- Es la primera excepción a "sin offline" del TRD: se apunta como ADR nuevo.

### 9.6 Fuera de alcance

Listas compartidas (decidido: la compra no se comparte), formato enriquecido e imágenes/adjuntos, etiquetas, reinicio programado de listas, reposición por calendario fijo ("cada sábado"), importe de la compra, historial de compras y enlace con gastos de Finanzas (descartado), sugerencias de frecuencia a partir del historial, dibujo, notas de voz, precios por producto y comparador, escaneo de tickets, sincronización con Notas o Recordatorios de iOS, widgets y Siri (candidatos a F+1, el widget de compra sería el primero).

### 9.7 Notas técnicas

En el TRD: reposición y sincronización (§4.1.4), esquema `notes` (§5.6), API (§6.5), caché y cola offline en la app (§7.6) y ADR-014.

### 9.8 Riesgos y críticas

| Tema | Comentario |
|---|---|
| Competir con Notas y Recordatorios de iOS | Recordatorios ya tiene listas de la compra con secciones automáticas, compartidas, con widget y Siri, y funcionan sin red. Lo que justifica hacerlo en carli: reposición por producto, funcionar offline y el enlace con Tareas. Si no aporta más que eso tras unas semanas, Recordatorios basta. |
| Offline | Ver §9.5. Es lo más caro del módulo (cola, caché, reposición duplicada en Dart y PHP). Sin ello la pestaña Compra falla en el peor momento. |
| Reposición por producto | Configurar frecuencia producto a producto es tedioso. Por eso el valor por defecto es "Sin repetir" y solo se configura en los que de verdad repites. |
| Notas de texto | Para apuntes largos, Apple Notes es mucho mejor (formato, imágenes, escaneo). El texto plano aquí sirve para notas rápidas, no para sustituirla. Mejor asumirlo que perseguirla. |
| Repetición duplicada | Hay dos formas de "repetir" (plantillas de Tareas y reposición de productos). La regla de §9.2 tiene que estar en la UI: bajo la reposición, una línea explica "No crea tareas ni avisos". |
| Carpetas multinivel | Con pocas notas, más de 2 niveles esconde cosas: la búsqueda y Recientes son las que de verdad las encuentran. Sin límite de profundidad, pero la UI no anima a anidar (crear subcarpeta va en el menú, no como botón principal). |
| Alcance | Las tres piezas (texto, listas, compra) son casi tres módulos. Orden propuesto: compra + listas primero, texto y carpetas después. |

### 9.9 Decisiones (2026-10-26)

1. Offline: **sí**, caché local + cola solo para Notas.
2. La compra **no se comparte** con nadie.
3. Notas de texto en **texto plano**.
4. Reposición **por producto y por intervalo** desde la última compra (NO-CO-04).
5. **Carpetas multinivel** (NO-11).
6. Enlace del gasto de la compra con Finanzas: **descartado**. La compra no guarda importe ni historial.

### 9.10 Estado (v1, 2026-10-26)

Implementado: todo lo Must, NO-07, NO-08, NO-10 (papelera 30 días), NO-LI-03, NO-CO-05 y NO-SH-02.

Pendiente:
- NO-09 (enlace desde Tareas, `tasks.note_id` y `task_templates.note_id`) y NO-LI-06 (convertir un elemento en tarea): siguiente entrega, ahora que Tareas está en `main`.
- Enlaces detectados en las notas de texto (abrirlos con un toque): hoy el cuerpo es un campo de texto plano sin detección.
- NO-CO-07 (pantalla siempre encendida en el súper).

## 10. Módulo Hábitos

Mockups (8 pantallas, claro y oscuro): https://claude.ai/artifact/Ua9uKcrvjXDgYRK5AEriLr

### 10.1 Conceptos

- **Hábito**: algo que quieres hacer con regularidad y donde lo que importa es la **constancia**, no una fecha límite. Nombre, icono, tipo, objetivo, fecha de inicio. No vence nunca.
- **Tipo**:
  - *Sí/No*: lo hiciste o no (meditar, gimnasio, leer).
  - *Cantidad*: con unidad y objetivo mínimo (8 vasos de agua, 20 páginas, 150 minutos).
  - *Evitar*: algo que quieres no hacer o limitar, con un **máximo** (0 por defecto). "No fumar" (máx. 0 al día), "Café" (máx. 2 al día), "Alcohol" (máx. 2 por semana). Lo que registras son las **recaídas** o consumos; un día sin registro cuenta como cumplido.
- **Objetivo** (la frecuencia de un hábito no es un calendario, es una meta por periodo):

| Objetivo | Ejemplo | Periodo que se evalúa |
|---|---|---|
| Cada día | Meditar | día |
| Días concretos | Gimnasio L, X, V | día (solo los marcados) |
| N veces por semana | Correr 3 veces/semana, cualquier día | semana (lunes a domingo) |
| Cantidad por día | 8 vasos de agua | día |
| Cantidad por semana | 150 min de ejercicio | semana |
| Evitar (máximo por día o semana) | Sin fumar; máx. 2 cafés al día; máx. 2 cervezas por semana | día o semana |

- **Registro**: un valor por hábito y día (1 en Sí/No, la suma en Cantidad). Se puede registrar cualquier día pasado desde el inicio del hábito.
- **Periodo cumplido / no cumplido / en curso / excusado**. Calculado, nunca guardado.
- **Constancia**: % de periodos cumplidos en las últimas 4 semanas. Es la **métrica principal**.
- **Racha**: periodos cumplidos seguidos (en Evitar se muestra como "12 días sin"). El periodo en curso no la rompe hasta que termina. Métrica secundaria (ver 10.8).
- **Descanso**: rango de fechas (vacaciones, enfermo) en el que no se evalúa nada. Para todos los hábitos o para uno. No rompe la racha ni baja la constancia.

### 10.2 Frontera con Tareas

Regla: **Tareas dice qué toca hacer y cuándo; Hábitos mide con qué constancia lo haces.** Una cosa es plantilla *o* hábito, nunca las dos.

| Caso | Dónde | Por qué |
|---|---|---|
| Pagar la comunidad el día 1 | Tareas (plantilla) | Tiene fecha; si no se hace, vence y debe salir en Pendientes |
| Sacar la basura L, X, V | Tareas (plantilla) | Es una obligación con día. Si no la haces, sigue pendiente |
| Gimnasio 3 veces por semana | Hábitos | Sin día fijo; importa la semana, no el día |
| Beber 8 vasos de agua | Hábitos | Cantidad que se acumula a lo largo del día |
| Meditar cada día | Hábitos | Si un día no lo haces, ese día se pierde; no queda nada "vencido" |

Diferencias de comportamiento que justifican dos módulos:

1. Un hábito **no vence**: el día que no lo haces queda como no cumplido y desaparece. Nunca entra en Pendientes.
2. Un hábito tiene **objetivos flexibles** (N veces por semana) y **cantidades**; una plantilla de Tareas no.
3. Un hábito se mide con **constancia y racha**; una tarea con hecha / no hecha.

### Cómo se conectan (decidido)

**A. Los hábitos de hoy aparecen en Hoy de Tareas** (Hábitos → Tareas). Hoy de Tareas gana una fila de anillos "Hábitos" encima de las tareas, con los hábitos que tocan hoy y aún no están cumplidos. Un toque registra (Sí/No) o suma 1 (Cantidad); mantener pulsado abre el registro de cantidad. Los hábitos *Evitar* no salen en la fila (no hay nada que hacer). No son tareas: no se guardan en `tasks`, no cuentan en "3 de 7", no vencen ni van a Pendientes. Se puede apagar por hábito ("Mostrar en Hoy de Tareas").

**B. Convertir una plantilla en hábito** (Tareas → Hábitos). Desde una plantilla, "Convertir en hábito": crea el hábito con el objetivo deducido de la RRULE (`FREQ=DAILY` → cada día; `WEEKLY;BYDAY=MO,WE,FR` → días concretos) e **importa el historial** de ocurrencias (TA-PL-09): *hecha* → registro, *saltada a mano* → descanso, *omitida / sustituida* → no cumplido. La plantilla queda pausada (se puede borrar después) y la tarea abierta de hoy se borra. Es una conversión única, no un vínculo vivo.

### Alternativa descartada: vínculo vivo plantilla ↔ hábito

Que una plantilla siga generando tareas y cada tarea hecha cuente para el hábito. Problemas:

- Dos dueños para lo mismo: hay que sincronizar hecha/deshecha en los dos sentidos (marcar en Hábitos debe completar la tarea, deshacer la tarea debe borrar el registro).
- Tareas tendría que cambiar su semántica para esas plantillas: no vencer, cerrarse solas a medianoche, no salir en Pendientes. Es justo lo que se decidió no hacer en Tareas (decisión 6).
- No encaja con "3 veces por semana": no hay días para generar tareas.

Lo que se pierde al no vincular: subtareas, lista y notas de la plantilla. Para un hábito no hacen falta; si una rutina tiene pasos (revisar el coche), es una tarea, no un hábito.

### 10.3 Requisitos funcionales

#### Hábitos
| ID | Requisito | Prio |
|---|---|---|
| HA-01 | Crear hábito: nombre, icono (de un set cerrado), tipo (Sí/No, Cantidad con unidad, Evitar con máximo y unidad), objetivo (10.1), fecha de inicio (hoy por defecto), hora orientativa opcional (solo ordena). | Must |
| HA-02 | Registrar con un toque en el anillo (Sí/No: marca; Cantidad: +1). Mantener pulsado: hoja con +/−, valor exacto y día. Deshacer en toast 4 s. | Must |
| HA-03 | Registrar o corregir días pasados desde el calendario del detalle. | Must |
| HA-04 | Editar hábito. Cambiar el objetivo aplica **desde hoy**: los periodos pasados se evalúan con el objetivo que tenían (se guarda el historial de objetivos). | Must |
| HA-05 | Pausar / archivar / borrar. Pausado: no sale en Hoy ni se evalúa. Archivado: fuera de la lista, conserva estadísticas. Borrar pide confirmación. | Must |
| HA-06 | Descansos: "Modo descanso" global (de / hasta) y descanso por hábito. Los días en descanso salen en gris en el calendario y no cuentan para nada. | Must |
| HA-07 | Reordenar hábitos (orden manual en Hoy y en la lista). | Should |
| HA-08 | Nota corta opcional en un registro ("10 km, rodaje suave"). | Could |
| HA-09 | Tipo *Evitar*: en Hoy sale aparte ("Evitar") con el botón "Registrar" (+1 recaída o consumo) y lo que queda ("1 de 2 cafés", "12 días sin"). Pasarse del máximo marca el periodo como no cumplido en ese momento. | Must |

#### Vistas
| ID | Requisito | Prio |
|---|---|---|
| HA-VI-01 | **Hoy**: anillo total del día ("3 de 5") y una tarjeta por hábito con su anillo (día o semana en curso), valor y racha. Los cumplidos bajan al final. Los semanales ya cumplidos salen como "Hecho esta semana". | Must |
| HA-VI-02 | **Hábitos**: todos los activos con objetivo en texto, constancia % y la semana actual en 7 puntos (L–D). Pausados y archivados abajo, plegados. | Must |
| HA-VI-03 | **Detalle**: constancia (4 semanas y desde el inicio), racha actual y mejor racha, calendario mensual (cumplido / no / descanso / futuro) y barras por semana para objetivos semanales o de cantidad. | Must |
| HA-VI-05 | **Progreso** (pestaña): constancia global (todos los hábitos, últimas 4 semanas) con su anillo, selector Semana / Mes / Año, cuadrícula hábitos × días del periodo, y lista de hábitos ordenada por constancia con la tendencia frente al periodo anterior (↑ / ↓ en la cifra, sin color). | Must |
| HA-VI-04 | Tarjeta en **Inicio**: "Hábitos · 3 de 5" con los anillos de los pendientes de hoy, registrables en línea. | Must |

#### Integración
| ID | Requisito | Prio |
|---|---|---|
| HA-TA-01 | Fila "Hábitos" en Hoy de Tareas (10.2 A). Solo si el módulo Hábitos está activo. | Must |
| HA-TA-02 | "Convertir en hábito" desde el detalle de una plantilla con RRULE diaria o semanal, con vista previa del historial importado (10.2 B). Plantillas "tras completarla", mensuales o anuales no se pueden convertir (no son hábitos). | Should |
| HA-SH-01 | **Pendientes**: los hábitos **nunca** entran. | Must |
| HA-SH-02 | **Aviso de las 20:00**: una línea "Te quedan 2 hábitos de hoy" si hay hábitos diarios sin cumplir, y "Correr: 1 de 3, quedan 2 días" solo cuando un objetivo semanal está en riesgo (días que quedan = veces que faltan). Los Evitar no entran. Sigue siendo un solo aviso. Desactivable. | Must |
| HA-SH-03 | Ajustes del módulo: mostrar en Hoy de Tareas (por defecto sí), línea en el aviso de las 20:00, primer día de la semana (lunes). | Should |

### 10.4 Reglas de cálculo

1. **Día**: Europe/Madrid. Un día cumple si `valor ≥ objetivo` (Evitar: `valor ≤ máximo`; sin registro = 0 = cumplido).
2. **Semana**: lunes a domingo. Sí/No semanal cuenta días con registro (máximo 1 por día); Cantidad semanal suma valores.
3. **Primera semana incompleta**: objetivo = `min(objetivo, días que quedan)`. Empezar un jueves "3 veces por semana" pide 3 de 4 días; empezar un sábado pide 2.
4. **Días concretos**: los días no marcados no se evalúan; registrar en uno de ellos cuenta como extra y no afecta.
5. **Racha**: periodos evaluables cumplidos seguidos hasta el último cerrado, más el actual si ya está cumplido. Descanso y días no marcados se saltan sin romperla.
6. **Constancia**: cumplidos / evaluables en las últimas 4 semanas cerradas + la actual si ya está cumplida (para no castigar el periodo en curso).
7. Nada de esto se guarda: se calcula al leer. Con un usuario y pocos hábitos son unos cientos de filas al año.

### 10.5 Notificaciones

Sin avisos por hábito en la v1, por el mismo motivo que Tareas (decisión 5: avisos a hora = TODO, sin APNs). La hora orientativa se guarda para cuando se decida. Solo la línea del aviso de las 20:00 (HA-SH-02).

### 10.6 Fuera de alcance

Hábitos compartidos o con amigos, logros e insignias, recordatorios por hábito, registro automático desde Salud (WHOOP/HealthKit: sueño, pasos), widgets, Siri. El modelo deja la puerta abierta a Salud con `source` en cada registro.

### 10.7 Notas técnicas

Detalle en TRD §4.1.5, §5.7, §6.6 y §7.7.


- Esquema `habits`:
  - `habits` (user_id, name, icon, kind `check|quantity|avoid`, unit, show_in_tasks, sort, start_date, preferred_time, paused_at, archived_at, converted_from_template_id).
  - `habit_goals` (habit_id, valid_from, period `day|week`, target numeric (mínimo; en `avoid`, máximo), days_of_week smallint[] nulo): historial de objetivos para HA-04.
  - `habit_entries` (habit_id, date, value numeric, note, source `manual|task_import|health`, unique `(habit_id, date)`).
  - `habit_breaks` (user_id, habit_id nulo = todos, from_date, to_date).
- Sin FK hacia `tasks`: la conversión lee el historial por un servicio del módulo Tasks (`TemplateHistoryReader`) y pausa la plantilla con su propio servicio. Hábitos no escribe en el esquema `tasks`.
- La fila de Hoy de Tareas la pinta la app llamando a `GET /habits/today` cuando el módulo está activo; el backend de Tasks no sabe nada de hábitos.
- `RecurrenceRule` de `Core/Recurrence` solo se usa para deducir el objetivo al convertir; los hábitos no usan RRULE.
- `HabitsDigestProvider` para la línea de las 20:00. No implementa `PendingItemsProvider`.
- `ModuleRegistry`: `habits` deja de ser "Próximamente".

### 10.8 Riesgos y críticas

| Tema | Comentario |
|---|---|
| Apps de hábitos se abandonan | Es el módulo con más riesgo de dejarse a las 3 semanas. Mitigación: registrar desde Inicio y desde Hoy de Tareas sin entrar al módulo, y pocos hábitos (avisar a partir de 7 activos). |
| Rachas | Una racha que vuelve a 0 por un mal día desmotiva más de lo que ayuda (efecto "ya la he roto, da igual"). Por eso la cifra grande es la constancia y la racha va en pequeño. |
| Anillos y color | Todos en ember, icono neutro (decidido). |
| Evitar sin registrar | Un día sin registro cuenta como cumplido, así que olvidarse de apuntar una recaída infla la constancia. Asumible con un solo usuario; no se pide confirmación diaria. |
| Cinco pestañas en Hábitos | Inicio · Hoy · Hábitos · Progreso + "+" caben, pero Progreso y el detalle repiten estadísticas. Progreso es la vista de conjunto; el detalle, la de un hábito. |
| Fila en Hoy de Tareas | Mezcla dos cosas en una pantalla. Se mitiga con anillos compactos (no filas de tarea) y sin contar en "3 de 7". Si molesta, se apaga en ajustes. |
| Online-only | Registrar un hábito con el Mac dormido falla. A diferencia de Notas, no es crítico: se registra luego (HA-03). No se propone offline. |
| Convertir plantilla | Pierde subtareas, lista y notas. Es intencionado (10.2). |

### 10.9 Decisiones (Juanda, 2026-10-27)

1. Conexión con Tareas: **fila de anillos en Hoy de Tareas + "Convertir en hábito" única**. Sin vínculo vivo.
2. Tipos en la v1: **Sí/No, Cantidad y Evitar**.
3. Métrica principal: **constancia %**; la racha en pequeño.
4. Anillos: **todos en ember**.
5. Pestañas: **Inicio · Hoy · Hábitos · Progreso** + botón "+".
6. Aviso de las 20:00: **incluye la línea de hábitos** (HA-SH-02, Must).
7. Descansos: **entran en la v1** (HA-06, Must).

### 10.10 Estado (v1, 2026-10-27)

Implementado: todo lo Must, más HA-07 (ordenar, desde la lista), HA-08 (nota en el registro), HA-TA-02 (convertir plantilla con vista previa) y HA-SH-03 (ajustes del módulo).

Detalles que fija la implementación:
- Cantidad semanal con primera semana incompleta: el objetivo se prorratea por días (`objetivo × días / 7`); Sí/No semanal usa `min(objetivo, días)` (10.4.3). Los días de descanso dentro de una semana cuentan igual que los días que faltan. En *Evitar* el máximo nunca se prorratea.
- Pausar o archivar deja de evaluar desde ese día; al reanudar, los días parado se guardan como descanso del hábito, así no rompen la racha.
- Un cambio de objetivo en mitad de la semana manda en toda esa semana (la semana se evalúa con el objetivo vigente al cerrarla, o hoy si está en curso). Cambiar dos veces el mismo día sobrescribe el cambio de ese día.
- El tipo de un hábito no se puede cambiar después de crearlo.
- Al convertir una plantilla se borran **todas** sus tareas abiertas, no solo la de hoy: una abierta atrasada de la política *acumular* seguiría saliendo en Pendientes. La tarea abierta de hoy no cuenta como "sin hacer" en la vista previa (hoy sigue en curso).
- Si en el aviso de las 20:00 solo hay líneas de hábitos, el aviso se titula "Hábitos de hoy" y abre `/habitos/hoy`.

Pendiente:
- Navegar a semanas, meses o años anteriores en Progreso (hoy muestra el periodo actual frente al anterior).
- Aviso al pasar de 7 hábitos activos: hoy es un texto en la lista, no un aviso al crear.


## 11. Requisitos no funcionales

- **Privacidad**: autoalojado en VPS propio; ningún dato sale a terceros salvo el servicio push del navegador (contenido cifrado extremo a extremo por Web Push).
- **Seguridad**: HTTPS obligatorio, 2FA opcional, rate limit en login, backups diarios cifrados de la BD fuera del VPS.
- **Rendimiento**: listado de 10.000 movimientos con filtros < 300 ms en servidor; LCP < 2,5 s en móvil 4G.
- **Accesibilidad**: WCAG 2.2 AA (contraste en ambos temas, foco visible, navegación por teclado).
- **Responsive**: desde 360 px de ancho.
- **Exactitud**: los importes nunca se calculan con coma flotante (ver TRD).

## 12. Riesgos y decisiones abiertas

| Tema | Comentario |
|---|---|
| Entrada solo manual | Es la principal causa de abandono en apps de finanzas. Mitigación: alta ultrarrápida, recurrentes automáticos y conciliación. Si a los 2 meses no se mantiene el hábito, reconsiderar importación CSV. |
| Push en iPhone | Solo funciona con la PWA añadida a la pantalla de inicio (iOS 16.4+). Hay que guiar la instalación. |
| Alcance F2 | Deudas + compartidos + objetivos son 3 mini-productos; priorizar según uso real. |
| Datos en un tercero (F3) | La sincronización bancaria hace pasar los movimientos por Enable Banking, en contra de uno de los motivos del producto (§2). Asumido: proveedor con licencia AISP en la UE, solo lectura, consentimiento revocable. |
| Proveedor bancario | Enable Banking puede cambiar o retirar el modo gratuito (como pasó con GoCardless/Nordigen). Mitigación: proveedor intercambiable (TRD); la app sigue funcionando en manual. |
| Revolut y MyInvestor en Enable Banking | No verificados (Revolut España; MyInvestor tiene API PSD2 vía Redsys pero no figura en los listados públicos de Enable Banking). Comprobarlo al enlazar en su panel antes de empezar F3. |
| Doble conteo (F3) | Lo manual y lo importado pueden duplicarse; responsabilidad del usuario. Mitigación: saldo del banco visible (FI-BK-07). |
| Periodo financiero | Decidido: de nómina a nómina con fecha variable (§7.5). Riesgo: si un mes no se registra la nómina, el periodo se alarga; se mitiga con el recurrente de la nómina en modo "con confirmación" y un aviso. |

## 13. Glosario

Patrimonio neto, saldo, conciliación, recurrente, split, rollover: ver §7.1.
