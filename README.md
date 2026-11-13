# Estacionómetros Delicias · implementación inicial

Primera entrega de la plataforma de tres portales, conservando HTML/JS sin dependencias para evolucionar el repositorio existente sin introducir una reescritura de framework.

## Accesos

- `/`: landing, reportes, comprobante y consulta con clave privada, buzón.
- `/panel`: correo/contraseña, turnos, GPS con app visible, reportes asignados, tickets y cortes.
- `/admin`: mapa Leaflet/OSM, catálogo, reportes, tickets/analítica, equipo, tarifas, cortes y buzón.

## Estado de la entrega

**Primera migración aplicada y verificada el 13/11/2026.** Se respaldaron las siete tablas originales, funciones, políticas y permisos en el esquema privado `ops_backup_20261113_pre_fase1`. Los 63 aparatos se conservaron. Tras dos confirmaciones vencidas del conector, la migración se ejecutó con éxito desde el editor SQL autenticado de Supabase en Chrome. Se verificó la existencia de tablas y endpoints con una consulta independiente.

`tests/database.sql` pasó sobre Postgres con datos sintéticos revertidos por ROLLBACK: turno idempotente, GPS, gracia de 15 minutos, bloqueo de multa, folios idempotentes, autoría, impresiones, aislamiento entre operadores, suspensión y seguimiento por token. Cinco pruebas Node también aprobadas.

**Segunda migración aplicada y verificada el 13/11/2026:** `db/operacion_accesos.sql`. Incluye activación inicial reservada al propietario con correo confirmado y lista privada, suspensión de operadores con cierre de turno/GPS, estado estructurado del aparato, reparación documentada y bitácora protegida. `tests/database_phase2.sql` pasó con ROLLBACK. La lista del propietario está configurada directamente en la base y no se publica en el repositorio.

Para iniciar Administración: abrir `/acceso?administracion`, registrar y confirmar el correo autorizado del propietario y entrar en `/admin`. La contraseña la define el propio usuario. Otros registros permanecen como operadores pendientes hasta su activación por Administración. No hay acceso Google ni autoasignación de roles por metadatos.

La migración contiene tablas nuevas, autoría de multas, RPCs de gracia/idempotencia, turnos/GPS, despacho al más cercano con posición reciente y reglas de lectura/escritura. No incluye tarifas inventadas ni aparatos de demostración. La primera tarifa debe cargarse con fundamento e importe autorizados. Sin tarifa activa no hay emisión.

La asignación inicial se realiza al recibir el reporte; no incluye todavía aceptación/timeout ni escalamiento automático. Los tableros consultan cada 15 segundos, no WebSockets. La impresión usa el diálogo del sistema, pendiente de validar con impresora mini física. No hay rastreo con pantalla bloqueada garantizado.

Pendiente: fotos verificadas de Facebook, evidencias fotográficas/Storage, Web Push, órdenes de mantenimiento avanzadas, exportación de bitácora, altas por invitación desde el portal, MFA, cola offline y mapas por zona y pruebas integrales con cuentas reales. El logotipo oficial aportado se incorporó sin distorsión a todos los portales, accesos, ticket, favicon e iconos PWA de 192 y 512 px.

Los módulos nuevos dependen de la migración. Login conserva las cuentas y roles existentes; los errores de conexión/esquema se muestran sin simular éxitos. La clave publicable existente se conserva; ninguna clave de servicio se incorpora al cliente.

Los tickets incorporan QR para validación por el personal autenticado en Administración. La ciudadanía permanece sin login y utiliza únicamente reporte/seguimiento y buzón.

## Comprobaciones

`npm test` y `npm run check` usan Node sin instalar dependencias. Para preview estático: `python3 -m http.server 4173 --directory .` y abrir `http://localhost:4173`. Las pruebas unitarias cubren escape HTML, fecha Chihuahua y separación de sesión/rol del cliente; no sustituyen pruebas de RLS del servidor.

Antes de aplicar SQL: exportar esquema/políticas y respaldar datos; probar en una base aislada la migración, idempotencia concurrente y roles anon/operador/admin; verificar pagos existentes y rutas `checkout.js` / `webhook.js`. Estos archivos de pagos se conservaron sin cambios: ya estaban en raíz y su disponibilidad como API Vercel sigue pendiente de auditoría. Se configuró Site URL en `https://estacionometros-delicias.vercel.app` y se autorizaron exclusivamente `/admin`, `/panel` y `/acceso` para confirmación/recuperación.

`db/plataforma_fase1.sql` es un script de entrega, no un historial CLI fabricado. CLI Supabase no está instalado. La primera fase se aplicó desde el editor SQL autenticado y la segunda mediante `apply_migration` con nombre `operacion_accesos`.

## Pruebas de base requeridas

1. Mismo UUID de solicitud/token: mismo folio y vencimiento.
2. Segundo reporte activo de igual placa/aparato: error sin extender gracia.
3. Una multa durante gracia: rechazo transaccional, incluso con concurrencia.
4. Anónimo no lee placas/teléfonos/perfiles; token incorrecto no devuelve reporte.
5. Operador no modifica multas ajenas ni identidad del destinatario de alerta.
6. Iniciar turno dos veces devuelve el mismo; cerrar limpia ubicación; ping sin turno falla.
7. Cuenta desactivada pierde permisos sensibles aunque conserve un JWT vigente.
8. La impresión registra intento, no confirmación de papel; reimpresión conserva folio.
9. Reporte sin candidato aparece a Administración; no se promete agente en camino.

Ver el plan integral en la rama `plan/plataforma-integral-2026-11-13` para alcance completo y fases posteriores.

## Pruebas de acceso reales

Se crearon dos cuentas de prueba solicitadas (operador y administrador) y se verificó HTTP 200 en el inicio de sesión y sus roles activos. Las contraseñas no se almacenan en el repositorio. La cuenta del propietario quedó activada tras confirmar su correo.

QRCode.js 1.0.0 está incluido localmente con licencia MIT. El QR del ticket apunta al portal administrativo y solo contiene el folio: requiere login del personal y no expone placas en la URL. La impresión física sigue pendiente de hardware real.

## Avisos y turno Android (0.3.0)

Firebase: `estacionometros-delicias`, aplicaciones web y Android `mx.estacionometros.delicias.operador`. Sólo Messaging; Supabase mantiene correo/contraseña. No se inicializa Analytics en los portales.

Los usuarios autenticados activan avisos por dispositivo, envían una prueba y los desactivan. Web Push cifrado utiliza VAPID; Chrome entrega a través de FCM. La instalación también se registra con el SDK Firebase cuando es compatible. `sw.js` muestra avisos generales y abre el portal; nunca guarda respuestas privadas. No hay avisos ni login para el conductor.

`db/notificaciones_push.sql`: suscripciones con RLS por propietario, cola privada idempotente, leases de 90 s, hasta seis intentos y cron cada minuto. `/api/push/config` expone sólo la clave pública y disponibilidad. `/api/push/dispatch` exige un secreto independiente y limita destinos a proveedores conocidos; nunca usa una service_role en el navegador. Configurar `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `PUSH_DISPATCH_KEY` como variables de producción (las dos últimas Secret). La URL y secreto del dispatcher se insertan sólo en `ops_private.push_config`, jamás en git.

Android 10+: fuente en `android/`. Inicia sesión en el portal de operación dentro de un WebView limitado al origen municipal. El puente sólo acepta mensajes del marco principal del origen HTTPS exacto. La sesión permanece en memoria, no en disco. Durante un turno, Android administra la renovación y las solicitudes para evitar carreras al renovar tokens desde la página y el servicio. Solicita ubicación precisa y notificaciones antes de iniciar. Un servicio de ubicación en primer plano envía posiciones nuevas cada 25 segundos, conserva precisión y rechaza capturas de más de 30 segundos; no requiere pantalla encendida. Cerrar turno o salir detiene el servicio. La notificación permite cerrar turno con conexión. El sistema puede detener el proceso por cierre forzado, permisos, batería o reinicio; al volver debe iniciar sesión/reactivar ubicación. No hay rastreo automático al arrancar el teléfono.

**Estado nativo:** el servicio consulta alertas asignadas cada 25 s durante el turno y las notifica. El receptor Firebase está integrado, pero el envío nativo FCM desde el servidor queda pendiente de configurar una identidad de servidor con permiso `cloudmessaging.messages.create`; no confundir esta consulta periódica con push nativo. El push web sí utiliza la cola y VAPID sin claves de cuentas de servicio Google.

Compilar: JDK 21, SDK 36, `cd android && ./gradlew assembleDebug lintDebug`. El APK debug es para pruebas; no es una versión Play firmada de producción. Validación física pendiente: Android con GPS preciso, caminar, minimizar/bloquear 10 minutos, comparar `ubicacion_at`/precisión en Administración, comprobar alerta y cierre de turno. También probar denegación de permiso, pérdida de red y restricción de batería. No afirmar continuidad en un teléfono hasta completar esa prueba.

Las tarifas continúan pendientes y la emisión permanece deshabilitada hasta contar con conceptos autorizados.
