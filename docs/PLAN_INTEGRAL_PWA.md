# Estacionómetros Delicias · Plan integral de producto y diseño PWA

Versión 1.0 · 13 de noviembre de 2026 · TheDevLogos

## 1. Resultado esperado y alcance

Una plataforma con tres experiencias separadas: atención al conductor, aplicación de campo y Centro de Operaciones. Comparten información transaccional y reglas del servidor, pero cada perfil ve únicamente lo necesario. La landing es pública; nunca muestra ubicaciones de empleados, placas ni evidencias privadas.

Este documento es una especificación para implementación y piloto; no acredita que los módulos nuevos estén funcionando ni constituye autorización municipal para emitir sanciones. Los 15 minutos solicitados se diseñan como regla operativa configurable que debe formalizar la autoridad antes de producción.

Prioridad: atención verificable, disponibilidad de aparatos y actuación correcta. La cantidad de multas es un indicador de actividad, no una meta individual de desempeño.

## 2. Diagnóstico comprobado del proyecto existente

Se consultó directamente el repositorio público thedevlogos-afk/Estaciono-metros-Delicias, el proyecto Supabase jawtbygyawivolwudpax y Vercel estacionometros-delicias, de la cuenta TheDevLogos.

| Elemento | Evidencia revisada | Decisión |
|---|---|---|
| Landing | index.html con reporte, consulta de multa y enlace a checkout | Rediseñar conservando enlaces QR existentes con parámetro p |
| Administración | admin.html con correo/contraseña, mapa Leaflet, reportes, cortes, equipo y consultas cada 15 s | Conservar funciones válidas; reemplazar navegación y completar módulos |
| Datos | parquimetros, reportes, multas, pagos, perfiles, cortes, alertas | Migración aditiva, preservando IDs y folios |
| Seguridad | RLS habilitada en las siete tablas | Revisar políticas y funciones; estar habilitada no demuestra aislamiento suficiente |
| Multas | No se observó operador emisor ni evidencia en el esquema | Añadir autoría, turno, cajón, revisiones y bitácora |
| Permisos de multas | mul_staff permite ALL bajo es_staff() | Reducir: operador crea propias y consulta alcance; no modifica libremente sanciones ajenas |
| PWA | manifest y sw.js básicos, precarga de portada | Manifiestos separados y cola transaccional; no basta para trabajar sin conexión |
| Despliegue | Vercel reporta último despliegue READY y dominios configurados | Verificar experiencia real en etapa de implementación; no se ejecutó QA del sitio |

Las tablas devolvieron rows: 0 en el inventario; esta cifra no sustituye un conteo exacto ni demuestra ausencia de datos. README.md, package.json e inspector.html devolvieron 404; no se infiere por ello que no exista otra ruta de campo. No se inspeccionó el árbol completo del repositorio ni el checkout/webhook de pagos.

El texto actual afirma cifras de aparatos, personal y antigüedad sin atribución. No se trasladarán automáticamente: la página municipal consultada habla de 11 zonas y tiene diferencias con ese texto. Catálogo, cifras y contactos deberán verificarse con Administración.

## 3. Arquitectura funcional y accesos

| Experiencia | Rutas propuestas | Identidad | Navegación |
|---|---|---|---|
| Ciudadanía | /, /conductor/reportar, /conductor/seguimiento, /conductor/buzon | Reporte rápido sin cuenta; seguimiento con token privado. Cuenta opcional con correo y contraseña | Inicio, Reportar, Seguimiento, Ayuda |
| Operador | /operador/acceso, /operador/hoy, /operador/mapa, /operador/incidencias, /operador/tickets | Cuenta institucional por invitación, activada por Administración | Hoy, Mapa, Alertas, Tickets, Perfil |
| Administración | /administracion/acceso y módulos internos | Correo y contraseña; segundo factor para privilegios administrativos | Operación, Activos, Incidencias, Multas, Equipo, Analítica, Buzón, Configuración |

Supabase Auth con contraseña es compatible con acceso independiente de Google. No se desarrollará almacenamiento propio de contraseñas. El rol se verifica en servidor y RLS mediante membresía protegida; nunca depende de un botón oculto, una ruta o metadatos editables por el usuario.

Operadores sin autorregistro de privilegios. Alta por invitación, recuperación por correo, control de sesiones, revocación y desactivación verificadas en cada operación sensible. Conductor no obtiene privilegios laborales al registrarse. Usar SMTP institucional antes del piloto.

Matriz: ciudadano crea sus reportes y consulta únicamente su seguimiento; operador consulta catálogo público, tareas asignadas y sus tickets; supervisor despacha y revisa su zona; mantenimiento atiende órdenes sin acceso financiero innecesario; caja concilia pagos; administrador gestiona personal y configuración; auditor consulta registros sin mutarlos. Separar permisos de cancelación y gestión de roles.

## 4. Flujo del conductor y gracia de 15 minutos

1. Escanear QR con ID de aparato y, si corresponde, cajón/lado. Alternativa: buscar número visible o elegir en mapa. Confirmar dirección y foto de referencia.
2. Elegir falla: no acepta monedas, moneda sin tiempo acreditado, pantalla apagada, daño físico u otra. Capturar placa, cajón/lado, detalle y contacto mínimo. Fotografía opcional salvo requisito formal aprobado; no impedir reportar si la cámara falla.
3. Mostrar aviso de privacidad y explicación exacta del alcance de la gracia. Enviar con clave de idempotencia.
4. El servidor valida aparato, deduplica reporte activo y registra received_at, grace_starts_at y grace_expires_at = received_at + 15 minutos. Retorna folio y token privado de seguimiento.
5. Pantalla de confirmación con aparato, placa parcialmente oculta, vencimiento absoluto, contador, estatus y botón para guardar comprobante. El contador deriva del reloj del servidor; cambiar la hora del teléfono no cambia vigencia.
6. Crear incidencia y despacho al operador elegible más cercano. Administración la recibe de inmediato aunque nadie esté disponible.
7. Operador acepta, llega, verifica y documenta resultado. Conductor ve una actualización comprensible; Administración conserva todo el expediente.

El reporte protege únicamente la combinación placa + aparato + cajón durante el intervalo registrado. No acredita automáticamente que el aparato esté averiado ni permite renovar indefinidamente la gracia. Un reporte duplicado devuelve la vigencia original. Quejas y sugerencias no generan gracia.

Durante gracia activa el servidor bloquea emitir una multa por falta de tiempo para esa combinación y muestra el motivo. Otro motivo requiere fundamento independiente y evidencia. Al cumplirse 15 minutos, si sigue pendiente la revisión, enviar a supervisión: no generar una multa automática. Una eventual extensión será una acción autorizada, con motivo y registro. Si se confirma falla, mantener el aparato fuera de servicio hasta reparación y mostrar al conductor la instrucción aprobada por la autoridad. Si no se confirma, informar resultado y opciones; no crear sanciones retroactivas automáticas.

Sin conectividad: permitir preparar borrador, mostrando “Aún no enviado; no hay folio ni gracia activa”. La gracia empieza al recibir el servidor, no con un contador local. Proporcionar canal alternativo oficial una vez validado.

Seguimiento privado: token aleatorio de alta entropía almacenado como hash, con expiración y rotación; folio solo no revela placa, teléfono o fotos. Sesión/token de seguimiento fuera de URL cuando sea posible; sin analítica de terceros en estas pantallas. Adjuntos privados con URLs temporales.

Buzón: categoría, descripción, ubicación opcional, archivo opcional, contacto voluntario o envío anónimo. Folio, acuse, asignación y estados recibido/en revisión/respondido/cerrado. No publicar quejas ni datos personales.

## 5. Aplicación de campo

Inicio de turno: autenticación, zona, dispositivo, batería, permisos de ubicación, prueba de conexión e impresora. Ubicación solo durante turno activo; indicador persistente y cierre explícito. Inicio “Hoy”: tareas pendientes, alertas prioritarias, última sincronización y botón grande “Revisar aparato”.

Verificación: escanear QR, validar ubicación con precisión registrada, confirmar aparato/cajón y elegir con tiempo, tiempo agotado, sin vehículo, falla o no verificable. “Sin saldo” significa tiempo visible agotado observado por el operador; no implica que la plataforma conozca electrónicamente el saldo.

Emisión: placa y jurisdicción, tipo/color de vehículo según formato aprobado, aparato/cajón, motivo del catálogo, evidencia, hora y coordenadas. Vista previa y confirmación. El servidor valida turno, permisos, gracia y duplicidad, calcula importe con tarifa versionada y crea folio único. Ningún importe libre salvo permiso expreso y auditado.

Ticket: institución, folio, fecha/hora de Chihuahua, identificación del operador, ubicación, placa, motivo, fundamento y tarifa aprobados, desglose, QR de consulta y vías oficiales de aclaración. No imprimir teléfono del conductor ni datos del denunciante. No inventar fundamento, montos, retención de placas ni instrucciones de pago.

Estados de multa: borrador → emitida → notificada → pagada / en aclaración / cancelada. Impresión es un estado independiente: pendiente, enviada a impresora, confirmada por operador, error, reimpresa. Enviar bytes a una impresora no demuestra que salió papel. Reimpresión conserva folio y marca “COPIA”; cancelación exige responsable y motivo, nunca borra expediente.

Alertas: sonido/vibración cuando esté permitido, aceptación, rechazar con motivo, ruta peatonal y ficha de verificación. No mostrar ubicación precisa de otros operadores al conductor.

Sin conexión: IndexedDB para borradores y evidencias pendientes, cola con UUID y reintentos exponenciales; reintentar al abrir y recuperar conexión. No depender solo de Background Sync. Primera fase: no imprimir una multa oficial sin validación en servidor, porque no se puede verificar una gracia recién creada. Eventual emisión offline requiere una política municipal separada, folios reservados y conciliación; no se promete como funcionalidad inicial.

## 6. Despacho y ubicación en tiempo real

Posición propuesta cada 20–30 s con aplicación visible y turno activo; reducir frecuencia en reposo. Guardar received_at, captured_at, accuracy_m, fuente y secuencia. Marcar reciente ≤90 s, desactualizada >90 s y sin señal >5 min como parámetros de piloto. No dibujar una posición antigua como actual.

Elegibilidad: empleado activo, turno abierto, zona habilitada, disponibilidad y ubicación reciente con precisión aceptable. Ordenar por distancia geodésica con PostGIS; usar tiempo peatonal si después se contrata un servicio de rutas. Distancia recta es aproximación, no ETA garantizada.

Asignación mediante transacción y bloqueo: ofrecer al primero; aceptación en 45 s, luego siguiente; escalar al supervisor en 2 min sin aceptación. Todos los tiempos son configuración inicial de piloto. Operadores ocupados o sin señal quedan excluidos. Si no hay candidatos, la incidencia permanece visible en Administración sin prometer “agente en camino”.

Push Web para aviso y Realtime para pantallas abiertas; ambos complementan una bandeja durable. Registrar entregado cuando sea verificable, leído y aceptado por separado. La pérdida de un push no pierde la tarea. Web Push exige permiso y compatibilidad; prever bandeja/polling y canal institucional de contingencia.

Límite: PWA no garantiza GPS continuo con pantalla apagada o aplicación cerrada. Para seguimiento obligatorio durante todo el turno se recomienda cliente Android con servicio de ubicación en primer plano, aviso persistente y políticas de privacidad, compartiendo backend y diseño. Medir PWA primero con teléfonos reales; no presentar una envoltura TWA como solución automática al rastreo en segundo plano.

## 7. Centro de Operaciones

Pantalla principal escritorio: barra lateral de 240 px; encabezado con turno/fecha y estado de conexión; cuatro tarjetas de servicio; mapa central de aproximadamente 60% del espacio y bandeja de incidencias a la derecha. En móvil: tarjetas, selector Mapa/Lista y ficha inferior, sin encoger el tablero completo.

Mapa Leaflet/OSM: capas de aparatos, cajones, zonas, operadores y fallas; agrupación al alejar, filtros por zona/estado/antigüedad, búsqueda por ID, leyenda y atribución visible. Aparato seleccionado abre ficha con foto, dirección, estado observado, fuente, última revisión, reportes e historial. Operador muestra antigüedad y precisión GPS, tarea y turno. No publicar rutas del personal.

Módulos:
- Activos: alta/importación CSV con validación, duplicados, coordenadas y vista previa; aparato, serie, modelo, zona, cajones/lados, QR, foto y mantenimiento.
- Incidencias: bandeja ordenada por vencimiento, gravedad y antigüedad; asignar, reasignar, verificar, crear orden y cerrar con evidencia.
- Multas: folio, operador, turno, zona, importe, estatus, evidencia, impresiones, aclaraciones y conciliación.
- Equipo: invitaciones, permisos, zonas, turnos, impresoras/dispositivos y suspensión; auditoría de cambios de rol.
- Mantenimiento: diagnóstico, orden de trabajo, técnico, piezas, causa raíz, fechas y prueba de funcionamiento antes de volver a servicio.
- Buzón: responsable, fecha compromiso, respuesta, anexos y seguimiento.
- Configuración: motivos, tarifas vigentes, horarios, reglas de gracia, SLA, plantillas y textos oficiales, con versiones.

Estados separados del aparato: operativo observado, falla reportada, falla confirmada, en mantenimiento y retirado. Telemetría: en línea/sin comunicación/desconocida. Ocupación y tiempo: desconocido/con medición compatible. “Sin comunicación” no significa “apagado”; “sin actividad” no significa “sin uso”.

## 8. Analítica y definiciones

| Indicador | Definición y filtro |
|---|---|
| Multas emitidas | Conteo de folios únicos por fecha de emisión; excluir borradores |
| Importe emitido | Suma de importes de emisión; mostrar cancelaciones por separado |
| Cobrado | Pagos confirmados por fecha de pago; separado de recaudación de monedas |
| Saldo pendiente | Importe exigible menos pagos confirmados y ajustes autorizados |
| Atención | Mediana y percentil 90 desde recepción hasta aceptación/llegada/cierre |
| Gracia | Reportes con verificación dentro de 15 min / reportes elegibles |
| Disponibilidad | Tiempo operativo confirmado / tiempo programado; separar tiempo desconocido |
| Cobertura | Aparatos distintos verificados / aparatos asignados al turno |
| Reincidencia | Aparatos con fallas repetidas en periodo; indicar umbral |
| Calidad | Cancelaciones, aclaraciones procedentes y expedientes sin evidencia |

Gráficas: serie por hora/día, barras por zona, distribución por motivo, embudo de atención, mapa de concentración y comparativo semanal/mensual. Tablas por operador con horas efectivas, cobertura, atención y calidad; evitar ranking de sanciones como incentivo. Filtros persistentes, exportación CSV/PDF con alcance y fecha.

Servidor agrupa periodos en America/Chihuahua, almacena UTC y usa intervalos [inicio, fin). Comparar periodos equivalentes. Mostrar última actualización, fuente y estado “sin datos”; no pintar ceros ficticios. Realtime invalida consultas; agregados diarios e índices evitan descargar todo el histórico.

## 9. Diseño visual y contenido

Identidad: logotipo azul aportado por el usuario, sin distorsión, conservando proporción. Paleta propuesta: azul institucional #073880, azul profundo #06235A, fondo #F4F7FC, texto #14243B; verde #147D57, ámbar #A65C00 y rojo #BA3038 con texto/icono adicional. Tipografía de sistema o Inter autoalojada. Radio 12–16 px, sombras discretas, jerarquía sobria y amplia separación.

Landing: encabezado limpio con identidad y enlaces de ayuda; fotografía auténtica del centro con degradado azul, título “Estacionar mejor. Atender más rápido.” y botón principal “Reportar una falla”. Botón secundario “Consultar mi reporte”. Después: cómo funciona, mapa público de aparatos, preguntas, avisos vigentes y contacto. Accesos de personal discretos en pie de página; no obligar al conductor a elegir entre tres roles.

Campo: botones de al menos 48 px, texto base 16–18 px, contraste para luz solar, formulario de una columna, captura asistida por QR y confirmaciones breves. Administración: alta densidad moderada, tablas legibles y acciones por contexto. Diseño a 360, 390, 768, 1280 y 1440 px; sin desplazamiento horizontal general. Accesibilidad WCAG 2.2 AA como objetivo: etiquetas, teclado, foco, estados narrados y alternativas al color.

Pantallas especificadas: landing; reporte paso a paso; acuse/contador; seguimiento; buzón; acceso/recuperación; hoy/turno; escáner/ficha; nueva multa/vista previa; impresión; alertas; mapa operativo; expediente; catálogo; órdenes; personal; analítica; configuración.

Estados obligatorios en cada diseño: carga, vacío, error recuperable, sin conexión, falta de permiso, sesión vencida y datos desactualizados. No afirmar que todos los aparatos tienen QR ni que todos los reportes serán atendidos en 15 minutos sin despliegue y capacidad verificados.

Facebook solicitado: https://www.facebook.com/estacionometrosdelicias no pudo consultarse por bloqueo de acceso. Fotografías y publicaciones de esa página quedan pendientes de selección verificada. No se usaron fotografías sustitutivas atribuidas a Facebook. Preparar inventario de 6–10 imágenes auténticas: centro, aparato, operador, mantenimiento y beneficio social; registrar URL/post, fecha, autoría y permiso. No reutilizar datos de ciudadanos visibles en comentarios. El portal municipal sirve para contraste institucional, no para presumir vigencia de todo el contenido.

## 10. Arquitectura técnica propuesta

Repositorio existente como fuente. Evolución sugerida a TypeScript + React/Vite para las tres interfaces, API server-side en Vercel y Supabase Postgres/PostGIS, Auth, Storage privado y Realtime autorizado. Adoptar framework después de inventariar las demás rutas/API; no reescribir pagos a ciegas.

Tres entradas y manifiestos: ciudadano, operador y administración. Scope de service worker de operador /operador/ y cachés versionadas independientes. Nunca cachear respuestas privadas o sesiones en caché pública; limpiar datos locales al cerrar sesión/cambiar usuario. CSP, validación de entrada, escape de HTML, límites de adjuntos y eliminación de EXIF innecesario. Secretos solo en servidor, clave publicable en frontend con RLS efectiva.

API propuesta: POST /api/reportes, GET /api/seguimiento, POST /api/buzon; POST /api/turnos/iniciar y /cerrar; POST /api/ubicaciones; POST /api/asignaciones/:id/aceptar; POST /api/verificaciones; POST /api/multas; POST /api/multas/:id/impresiones; POST /api/multas/:id/aclaraciones; GET /api/operacion/resumen; POST /api/telemetria. Todas las escrituras tienen idempotencia y autorizaciones verificadas; creación de multa/gracia se serializa para impedir carreras.

Outbox transaccional para notificaciones y trabajos: el evento se registra junto con el reporte; reintentos con backoff, dead-letter y alerta a supervisión. Usar cola durable/worker o tarea programada, no temporizadores en memoria de una función Vercel. No mantener sockets propios en funciones: Realtime maneja conexión cliente.

Mapas: Leaflet con datos OSM, atribución © OpenStreetMap contributors. Tiles públicos no tienen SLA y no permiten descarga masiva para offline. Proveedor de tiles intercambiable; contratar capacidad si el volumen lo exige. Catálogo local puede funcionar offline, sin prometer mapa completo descargado.

## 11. Modelo de datos y migración

| Entidad | Campos/reglas principales |
|---|---|
| parquimetros existente | Preservar id; añadir modelo, serie, estado, fuente_estado, fecha_estado, foto y zona FK |
| zonas y cajones | Geometría de zona; cajón/lado único por aparato; historial de reubicación |
| perfiles/membresias | user_id, permisos protegidos, activo; no autoasignación de rol |
| turnos y asignaciones_zona | Operador, inicio, fin, supervisor, zona y estado |
| ubicaciones_actuales/historial | Operador, precisión, captura/recepción y turno; retención diferenciada |
| reportes existente | Añadir cajón, recepción, clasificación y vínculo a incidencia; conservar folio/gracia |
| protecciones_gracia | Placa normalizada, aparato/cajón, inicio/fin, regla y motivo de extensión |
| despachos | Incidencia, candidato, ofrecida, aceptada, vencida y versión de asignación |
| verificaciones | Autor, turno, aparato/cajón, observación, GPS y hora servidor |
| multas existente | Añadir id interno, emisor, turno, verificación, tarifa_version y estado ampliado |
| evidencias e impresiones | Archivo privado/hash/autor; intentos de impresión y reimpresiones |
| ordenes_mantenimiento | Causa, prioridad, técnico, piezas, prueba final y cierre |
| quejas y respuestas | Folio privado, contacto opcional, clasificación, responsable e historial |
| dispositivos/telemetria | Clave por dispositivo, versión firmware, secuencia, batería y eventos crudos |
| auditoria/outbox | Actor, acción, entidad, hora, correlación; permisos sin borrado por operadores |

Índices: geometrías GiST; multas por emisor/fecha y estado/fecha; reportes por aparato/creado; tareas por asignado/estado; UUID de idempotencia único; dispositivo+secuencia único. Restricciones de estado y referencias; importes numeric con moneda MXN. Normalización de placa conserva original y jurisdicción, evitando fusiones ambiguas.

Migración: respaldo verificable → inventario de funciones/triggers/políticas/Storage → migración aditiva nullable → backfill → validaciones → actualización gradual de clientes → endurecer restricciones. Mantener compatibilidad de QR y folios antiguos. No eliminar pagos/cortes; separar cobro de multas y recaudación de aparatos. Rollback con feature flags y versión anterior; restaurar respaldo solo como procedimiento probado, no como sustituto de una migración reversible.

Auditoría pendiente: definiciones de es_staff, es_admin, crear_reporte, alertar_reporte y estadisticas; privilegios SECURITY DEFINER/search_path y grants. Verificar que alertas no permitan al destinatario reasignar inspector_id; políticas UPDATE deben impedir cambios de propiedad. Las políticas actuales observadas no prueban todas estas garantías.

Retención propuesta para evaluación: posiciones detalladas 30 días, después agregación; periodo definitivo de multas/evidencias según archivo y privacidad municipal. No aplicar borrado automático sin calendario aprobado. Placas, teléfonos, rutas y fotos son privados; exportaciones registradas y limitadas.

## 12. Impresora mini

Objetivo: ticket térmico de 58 mm, variante de 80 mm. PDF/HTML de respaldo. Validar acentos, Ñ, QR, líneas largas, papel agotado, desconexión, batería y reimpresión.

No comprar por la palabra “Bluetooth”: Web Bluetooth normalmente requiere BLE/GATT compatible y no garantiza impresoras ESC/POS de Bluetooth clásico. Elegir una impresora exacta y probarla con teléfonos reales. PWA puede usar impresión del sistema donde exista soporte; para operación robusta Android con Bluetooth clásico, integrar SDK del fabricante o puente nativo con permisos acotados. Navegadores/iOS no se consideran compatibles hasta prueba. La impresión no es comprobante de pago.

## 13. Telemetría, chip e instrumentación

No hay hardware instalado ni compatibilidad de fabricante verificada. Se conserva como restricción de diseño el caso sin acceso al interior: instrumentación exterior puede observar pantalla/actividad, pero no medir directamente aceptación de moneda o batería interna.

| Alternativa | Qué aporta | Qué no prueba | Decisión |
|---|---|---|---|
| QR y rondines | Revisión humana, estado y evidencia | Estado continuo | Primera fase obligatoria |
| Cámara/sensor óptico exterior | Lectura de pantalla o cambio visible, con calibración | Acreditación interna de todas las monedas; falla con reflejos/ocultamiento | Piloto controlado, encuadrando solo pantalla |
| Ocupación magnética/radar exterior | Presencia de vehículo | Saldo, depósito ni falla del aparato | Módulo independiente si se necesita ocupación |
| Interfaz del fabricante | Eventos confiables si el equipo expone protocolo | Compatibilidad universal | Mejor ruta, requiere modelo/documentación y autorización |
| Módulo interno de pulsos/voltaje | Monedas detectadas, energía, apertura según sensores | Tiempo acreditado si no hay lectura del controlador | Solo con acceso y autorización técnica |

Conectividad a evaluar en campo: LoRaWAN con gateway y estudio de cobertura, o LTE-M/NB-IoT/celular según disponibilidad del operador. Un ESP32 por sí solo no resuelve conectividad remota ni diagnóstico. Presupuesto incluye sensor, módem, batería, gabinete, fijación, instalación, conectividad y mantenimiento; cotizaciones posteriores a pruebas, sin precios ficticios.

Ingestión por HTTPS autenticado por dispositivo, firma/credencial rotatoria, secuencia y timestamp; deduplicación y protección contra repetición. Backend normaliza eventos y conserva fuente/confianza. Alertas por latido ausente separadas de apagado confirmado. Nunca emitir multas automáticamente por telemetría experimental.

Piloto sugerido: 5 aparatos representativos durante 2 semanas y 2–3 operadores. Comparar contra revisión humana: falsos positivos/negativos, lecturas válidas, latencia, consumo, cobertura, lluvia/sol y alteración del aparato. Criterios iniciales: ≥95% lecturas válidas, ≤5% falsos avisos y batería proyectada suficiente para mantenimiento acordado; ajustar al riesgo y al modelo. Sin acceso interior no prometer detectar cada moneda mal contabilizada.

## 14. Plan de ejecución y entregables

Estimación inicial para equipo pequeño, sujeta a inventario y piloto; semanas desde inicio, no fechas comprometidas.

| Fase | Duración orientativa | Entrega y salida |
|---|---|---|
| 0. Inventario y reglas | Semana 1 | Árbol completo, funciones, revisión de pagos, padrón, formatos oficiales, hardware y política de gracia |
| 1. Base y diseño | Semanas 2–3 | Diseño navegable validado, acceso sin Google, roles/RLS probados, migraciones y preview |
| 2. Ciudadanía y despacho | Semanas 4–5 | Reporte, token, gracia servidor, buzón, asignación/escala y notificaciones |
| 3. Campo y tickets | Semanas 6–7 | Turnos, revisión, GPS visible, multa, impresión física probada, borradores offline |
| 4. Operaciones y analítica | Semanas 8–9 | Mapa, expedientes, mantenimiento, conciliación y exportaciones |
| 5. Piloto y salida | Semanas 10–11 | Prueba de calle, ajustes, capacitación, restauración y monitoreo |
| 6. Telemetría opcional | Después de piloto técnico | Selección de hardware por evidencia y ampliación gradual |

Responsables: Administración valida operación y catálogos; área jurídica define fundamento/gracia/privacidad; supervisión valida rondines; TI desarrolla, protege y monitorea; operadores prueban; proveedor valida impresora/hardware. Insumos pendientes no impiden diseñar, pero sí activar reglas oficiales definitivas.

Entregables de implementación: código versionado, migraciones, diccionario de datos, contratos API, diseños responsive, plantillas de ticket, matriz de permisos, pruebas, manuales por rol, inventario de activos y procedimiento de contingencia. Trabajar en ramas/preview; separar datos de prueba y producción; salida gradual por zona y feature flags, sin llenar la producción de aparatos ficticios.

Costos: estimar horas por fase y cotizar separadamente Vercel, Supabase, almacenamiento/egreso, SMTP, tiles, notificaciones opcionales, impresoras, teléfonos y telemetría. Fórmula: usuarios activos × frecuencia GPS × horas de turno + reportes/evidencias + conservación. Ejemplo dimensionador, no padrón real: 20 operadores × 8 h × 120 posiciones/h = 19,200 posiciones por día a 30 s. Retener última posición separada del historial reduce consultas del tablero.

## 15. Pruebas y criterios de aceptación

- Dos envíos del mismo reporte producen un folio y una gracia; cambiar reloj o reinstalar no extiende vigencia.
- Reporte y multa concurrentes no evaden la protección; la validación sucede en la transacción del servidor.
- Conductor no lee reportes ajenos ni localización laboral; operador no cambia roles ni multas ajenas; cuenta suspendida pierde acciones sensibles aunque conserve token.
- Asignación simultánea solo permite un responsable activo; rechazo/silencio reasigna y queda auditado; sin GPS reciente no se anuncia proximidad fiable.
- Campo se prueba con ubicación denegada, aplicación minimizada, pantalla bloqueada, batería baja y pérdida de red; el tablero muestra antigüedad.
- Ticket se imprime en hardware real con QR legible y acentos; reimpresión no duplica folio; error de papel no pierde registro digital.
- Cerrar sesión limpia borradores privados del dispositivo o ofrece recuperación controlada sin exponerlos al siguiente usuario.
- Totales por día/semana/mes coinciden con consultas de control, contemplando cancelaciones, pagos parciales y límite horario Chihuahua.
- Realtime/push caídos no pierden tareas; tablero reconecta y recupera eventos. Nunca se indica “enviado” antes del acuse durable.
- Importación rechaza coordenadas inválidas/duplicados y genera informe de errores antes de aplicar.
- Restauración de respaldo, rollback de interfaz y contingencia operativa ensayados antes de salida.
- Objetivos de piloto: acuse online p95 <3 s y actualización de tablero <10 s en red de prueba; no son SLA contratados. Cero filtraciones entre roles y cero duplicación de folios en pruebas de concurrencia.

## 16. Fuentes y límites de verificación

- Repositorio: https://github.com/thedevlogos-afk/Estaciono-metros-Delicias (index.html, admin.html, sw.js, manifest.webmanifest leídos el 13/11/2026).
- Supabase y Vercel: inventario autenticado del proyecto y políticas RLS, consulta de lectura el 13/11/2026. No se modificó la base ni configuración de producción para este plan.
- Institución: https://municipiodelicias.com/nosotros-estacionometros.html. Contiene misión, objetivo y referencia a 11 zonas; datos históricos deben confirmarse.
- Acceso por contraseña: https://supabase.com/docs/guides/auth/passwords
- Seguridad: https://supabase.com/docs/guides/database/postgres/row-level-security y https://supabase.com/docs/guides/realtime/authorization
- Compatibilidad de impresión: https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API
- Uso de mapas: https://operations.osmfoundation.org/policies/tiles/
- Fuente visual solicitada pendiente: https://www.facebook.com/estacionometrosdelicias

La conexión de Chrome identificó el perfil Alonso, pero no ofreció pestañas utilizables y devolvió un error de conexión. No se tomó control de la sesión de Google ni se verificaron publicaciones de Facebook. La clonación local falló por resolución de red; la lectura del repositorio se realizó mediante el acceso conectado a GitHub. Este documento no sustituye pruebas de la aplicación ni presenta la nueva plataforma como desplegada.
