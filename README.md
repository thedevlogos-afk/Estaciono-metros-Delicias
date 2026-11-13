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

Pendiente: fotos verificadas de Facebook, evidencias fotográficas/Storage, QR del ticket, Web Push, órdenes de mantenimiento avanzadas, exportación de bitácora, altas por invitación desde el portal, MFA, cola offline y mapas por zona y pruebas integrales con cuentas reales. El logotipo oficial aportado se incorporó sin distorsión a todos los portales, accesos, ticket, favicon e iconos PWA de 192 y 512 px.

Los módulos nuevos dependen de la migración. Login conserva las cuentas y roles existentes; los errores de conexión/esquema se muestran sin simular éxitos. La clave publicable existente se conserva; ninguna clave de servicio se incorpora al cliente.

## Comprobaciones

`npm test` y `npm run check` usan Node sin instalar dependencias. Para preview estático: `python3 -m http.server 4173 --directory .` y abrir `http://localhost:4173`. Las pruebas unitarias cubren escape HTML, fecha Chihuahua y separación de sesión/rol del cliente; no sustituyen pruebas de RLS del servidor.

Antes de aplicar SQL: exportar esquema/políticas y respaldar datos; probar en una base aislada la migración, idempotencia concurrente y roles anon/operador/admin; verificar pagos existentes y rutas `checkout.js` / `webhook.js`. Estos archivos de pagos se conservaron sin cambios: ya estaban en raíz y su disponibilidad como API Vercel sigue pendiente de auditoría. Los redirects de correo de Auth deben incluir el dominio de producción y `/acceso`.

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
