# PRD · Personal App (shell modular + módulo Finanzas)

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
| **F4+** | Otros módulos: Tareas, Salud, Hábitos, Notas (solo se reserva su hueco en el shell) |

> Recomendación: no empezar F2 hasta usar F1 dos o tres semanas. Lo que eches en falta en el uso real pesa más que este documento.

### 5.2 Fuera de alcance (explícito)

- Importación CSV/Excel.
- Deduplicación o emparejamiento automático entre movimientos manuales e importados del banco (lo resuelve el usuario).
- Iniciación de pagos (PIS): la conexión bancaria es solo de lectura.
- Movimientos pendientes (no contabilizados) del banco.
- Multimoneda, inversiones, cripto.
- Modo offline / sincronización.
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
| FI-BK-01 | Conectar un banco desde Ajustes → Bancos: elegir banco, redirección al banco para autorizar (SCA), volver a la app y **vincular cada cuenta del banco a una cuenta existente** o crear una nueva. | Must |
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
| FI-BK-12 | **Detección automática de transferencias** entre cuentas conectadas: al terminar cada sincronización, un gasto importado en una cuenta y un ingreso importado en otra, con el mismo importe y a 3 días o menos, son pareja candidata. Si es el **único** candidato en ambos sentidos y hay al menos una señal fuerte (IBAN de la contraparte = la otra cuenta, contraparte = el titular, o concepto de traspaso propio / nombre del otro banco), y ninguno de los dos tiene categoría, se convierten solos en transferencia (no cuentan como gasto ni ingreso). Se marcan como "Detectada" y se pueden **deshacer**: vuelven a gasto e ingreso sin categoría y esa pareja no se vuelve a proponer. Tras "Sincronizar ahora" se avisa de cuántas se han detectado. | Must |
| FI-BK-13 | Las parejas dudosas (solo importe y fecha, varios candidatos o algún movimiento ya categorizado) aparecen en Pendientes como **"¿Es una transferencia entre BBVA y Revolut?"** con *Confirmar* y *No es transferencia* (que se recuerda). Mientras un movimiento esté propuesto como transferencia no aparece además como "sin categoría" en Pendientes. | Must |
| FI-BK-14 | Transferencia con una cuenta **sin conexión** (p. ej. MyInvestor manual): en el detalle de un gasto o ingreso importado, "Es una transferencia a/desde…" eligiendo una cuenta manual. El importado pasa a ser una pata y se crea la otra en la cuenta manual. Deshacer borra la pata creada. Importe, fecha y cuenta del importado siguen sin poder cambiarse. | Should |

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
| Recurrente pendiente de confirmar | Día del cargo, 09:00 | On |
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

## 8. Requisitos no funcionales

- **Privacidad**: autoalojado en VPS propio; ningún dato sale a terceros salvo el servicio push del navegador (contenido cifrado extremo a extremo por Web Push).
- **Seguridad**: HTTPS obligatorio, 2FA opcional, rate limit en login, backups diarios cifrados de la BD fuera del VPS.
- **Rendimiento**: listado de 10.000 movimientos con filtros < 300 ms en servidor; LCP < 2,5 s en móvil 4G.
- **Accesibilidad**: WCAG 2.2 AA (contraste en ambos temas, foco visible, navegación por teclado).
- **Responsive**: desde 360 px de ancho.
- **Exactitud**: los importes nunca se calculan con coma flotante (ver TRD).

## 9. Riesgos y decisiones abiertas

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

## 10. Glosario

Patrimonio neto, saldo, conciliación, recurrente, split, rollover: ver §7.1.
