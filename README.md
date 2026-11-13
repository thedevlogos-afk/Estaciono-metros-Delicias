# Estacionómetros Delicias · PWA de operación

Plataforma web adaptable para atención ciudadana, operación en campo y el Centro de Operaciones. El proyecto conserva una base HTML, CSS y JavaScript ligera; Supabase gestiona autenticación, datos y reglas de operación.

## Portales

- **Ciudadanía — /**: mapa público de parquímetros, reporte sin cuenta, comprobante con gracia de 15 minutos, seguimiento con clave privada y buzón de quejas/sugerencias.
- **Operación — /panel**: acceso institucional, turnos, ubicación durante el turno, escaneo QR o captura manual, revisión física, avisos de falla, reportes asignados, tickets, impresión, cortes y perfil.
- **Administración — /admin**: resumen, mapa Leaflet/OSM, reportes, tickets y analítica, buzón, padrón y QR de aparatos, mantenimiento, equipo, cortes, tarifas y bitácora.
- **Accesos — /acceso**: registro controlado y recuperación de cuenta para personal; conserva visible el aviso de tarifas pendientes.

El conductor no tiene registro ni inicio de sesión. Cada portal utiliza el logotipo oficial entregado para el proyecto.

## Recordatorio permanente: tarifas pendientes

Las tarifas de infracción continúan pendientes. No se cargaron importes de ejemplo ni se habilitaron multas. La emisión seguirá bloqueada hasta que Administración capture el concepto, fundamento e importe oficialmente autorizados. El recordatorio aparece en la página ciudadana, los comprobantes, los accesos de personal, los portales de operación y administración, y esta documentación.

## Migraciones aplicadas

- Fase 1: reportes con gracia en servidor, seguimiento privado, turnos, ubicación, tickets con autoría, buzón y reglas de acceso.
- Fase 2: gestión de acceso, suspensión de operadores, estados de aparato, mantenimiento y bitácora.
- Revisión de operador: avisos de falla de campo con RLS y RPC, seguimiento administrativo y cierre al registrar una reparación.

Los scripts de entrega están en la carpeta db. No contienen credenciales de servicio. La migración de avisos de operador se aplicó al proyecto conectado y se verificaron RLS, permisos de lectura y ejecución de RPC.

## Estado operativo y límites

- Los avisos ciudadanos generan folio, registran los 15 minutos y buscan un operador con turno y GPS reciente. La asignación inicial no incorpora aún aceptación con timeout ni escalamiento automático.
- El Centro de Operaciones actualiza el mapa de operadores cada 5 segundos; los datos generales del panel se consultan cada 15 segundos. PWA activa y Android envían latidos GPS cada 10 segundos durante un turno; son actualizaciones frecuentes por consulta, no WebSockets.
- El mapa muestra solo aparatos con coordenadas reales. La ausencia de telemetría no se presenta como lectura de monedas ni como confirmación de uso.
- El servicio Android solicita lecturas GPS cada 10 segundos y envía la posición nueva con notificación visible y permiso preciso. Falta validar continuidad en equipos físicos. En PWA de navegador, bloquear o minimizar puede pausar GPS; al volver al primer plano la ubicación se reactiva y se muestra la conectividad, precisión y hora del último envío.
- Firebase Web Push está enlazado mediante VAPID. Chrome registró un dispositivo de prueba y el proveedor aceptó el envío; falta confirmar visualmente la notificación en el sistema operativo.
- La recepción de push nativo Android, la impresora mini real, las fotografías oficiales de Facebook y la carga privada de evidencia requieren pruebas o configuración adicionales. Facebook identifica a la institución y lista su sitio web, pero no expuso teléfono, correo, domicilio ni horarios en la vista pública.
- Cola offline, exportación de bitácora, filtros por zona y telemetría con chip son fases posteriores.

## Comprobaciones locales

Ejecutar npm test y npm run check desde la raíz del proyecto. Las pruebas locales verifican funciones del cliente y validaciones del dispatcher; no sustituyen pruebas de roles/RLS ni ensayos en dispositivos físicos.

La matriz de pantallas y límites de piloto está en docs/AVANCE_INTERFACES_2026-11-13.md.
