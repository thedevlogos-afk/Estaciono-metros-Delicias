# Interfaces y recorrido de operación · 13 de noviembre de 2026

> **Tarifas de infracción pendientes.** No se ha definido ni activado importe alguno. La emisión de tickets permanece bloqueada hasta que Administración capture el concepto, fundamento e importe oficialmente autorizados.

Esta matriz registra las pantallas que forman el recorrido actual y las verificaciones que faltan para un piloto físico. Conductor, operador y Administración conservan accesos separados. El conductor no crea cuenta ni inicia sesión.

## Ciudadanía · / (página pública)

| Pantalla | Acción disponible | Resultado |
|---|---|---|
| Inicio | Explicación del servicio y acceso directo a reportar | Entrada pública, adaptable a teléfono |
| Ubicar aparato | Mapa Leaflet/OSM, con los aparatos que tengan coordenadas válidas | Abrir el reporte desde un marcador o elegirlo por número |
| Reportar falla | Elegir aparato, describir falla, ingresar placa y monto depositado | El servidor crea el folio y registra la gracia de 15 minutos |
| Comprobante | Consultar folio, aparato, placa, vencimiento y guardar recibo | Referencia privada de seguimiento |
| Seguimiento | Folio y clave privada | Estado comprensible, vencimiento y siguiente paso |
| Queja o sugerencia | Envío anónimo opcional o con contacto voluntario | Folio del buzón, sin activar gracia |

Los marcadores usan el padrón oficial y no muestran información del personal. Si Administración aún no carga coordenadas, el mapa informa que la persona puede seleccionar el aparato por número. No se crea ubicación de muestra.

## Operación en campo · /panel

| Pantalla | Acción disponible | Resultado |
|---|---|---|
| Acceso | Correo y contraseña institucionales; aviso de tarifas pendientes visible antes del login | Sesión de operador verificada por rol |
| Hoy | Abrir/cerrar turno, activar ubicación y avisos | GPS vinculado al turno; guía de permisos visible |
| Revisar | Escanear QR con cámara o escribir el código del aparato | Ficha con dirección, coordenadas y estado registrado |
| Reportar falla | Elegir síntoma y describir observación de campo | Aviso durable para Administración; cambia estado si estaba operativo |
| Alertas | Revisar reportes ciudadanos asignados y registrar resultado | Seguimiento del reporte dentro del intervalo de gracia |
| Mapa | Ver aparatos georreferenciados | Apoyo para rondín, sin simular telemetría |
| Tickets | Capturar placa, motivo autorizado, confirmar verificación y previsualizar | Emisión server-side bloqueada si no existe tarifa activa |
| Cortes | Capturar importe y nota de recolección | Registro del corte asociado al aparato |
| Perfil | Ver nombre, límites del GPS web y guía de notificaciones | Cierre de turno explícito |

En Android, el servicio de ubicación persistente requiere permisos precisos y notificación visible. En una PWA de navegador, minimizar o bloquear puede pausar el GPS; no se promete seguimiento continuo en segundo plano. El escaneo QR requiere cámara compatible y segura; siempre queda la entrada manual como alternativa.

## Administración · /admin

| Pantalla | Acción disponible | Resultado |
|---|---|---|
| Resumen | Ver aparatos, reportes pendientes, turnos y GPS reciente | Lectura general actualizada cada 15 segundos |
| Mapa operativo | Ver aparatos, fallas y posición reciente del personal | Las posiciones antiguas se marcan como desactualizadas |
| Reportes | Revisar avisos ciudadanos y alertar al operador elegible más cercano | Bandeja durable; si no hay operador reciente se indica |
| Tickets y analítica | Buscar folio y consultar volumen/importes por 24 horas, semana o mes | Importe emitido separado de importe cobrado |
| Buzón | Consultar quejas/sugerencias y actualizar su estado | Seguimiento administrativo |
| Parquímetros | Registrar aparato real con calle, zona y coordenadas | Etiqueta QR imprimible que abre el formulario ciudadano |
| Mantenimiento | Consultar fallas reportadas desde campo, tomar una revisión, registrar reparación y prueba | Se cierran avisos abiertos al restablecer el aparato |
| Equipo | Activar/desactivar acceso de operadores | La suspensión cierra el turno y elimina la ubicación retenida |
| Cortes | Consultar recolecciones registradas | Separados de multas |
| Tarifas | Registrar versión con fundamento autorizado | Mantener pendiente mientras falte validación oficial |
| Bitácora | Consultar cambios sensibles | Evidencia administrativa de actividad |

La pantalla de acceso y recuperación mantiene visible el recordatorio de tarifas pendientes. La lectura de avisos de aparato requiere sesión; RLS permite verlos a Administración y al operador emisor. La creación y cambios de estado usan RPC con validación de rol y turno.

## Límites por validar antes del piloto

- Cargar el padrón y coordenadas verificados por Administración. La base debe contener aparatos reales; no se agregan registros ficticios.
- Mantener tarifas pendientes hasta recibir fundamento e importes oficiales. No habilitar tickets de prueba con importes inventados.
- Probar entrega visible de push web y Android en equipos físicos; la aceptación del proveedor confirma recepción técnica, no visualización en pantalla.
- Probar GPS al caminar, minimizar, bloquear, perder conexión, denegar permisos y cerrar el turno en modelos Android y navegadores objetivo.
- Probar ticket y código QR en la impresora mini seleccionada, con papel real, acentos y reimpresión.
- Integrar evidencia fotográfica privada cuando se definan retención, permisos y aviso de privacidad.
- Incorporar fotografías de Facebook únicamente tras seleccionar y confirmar material institucional reutilizable. El logotipo entregado por el usuario ya está aplicado.
- Diseñar la electrónica/chip para autodiagnóstico solo después de identificar modelo, acceso eléctrico, cobertura y pruebas sin intervenir el interior.
- El panel consulta cada 15 segundos. Aceptación/timeout/escalamiento automático, cola offline y trabajo con rutas/zonas ampliadas siguen siendo fases posteriores.

## Fuentes institucionales verificadas

La página pública [Facebook Estacionómetros Delicias](https://www.facebook.com/estacionometrosdelicias) identifica al Consejo Municipal de Estacionómetros de Delicias y lista [estacionometrosdelicias.com](http://www.estacionometrosdelicias.com/) como sitio web. La [imagen de perfil](https://www.facebook.com/photo/?fbid=1022159306607894&set=a.490878163069347) y la [portada](https://www.facebook.com/photo/?fbid=1022159129941245&set=a.490878173069346) muestran un parquímetro y la identidad institucional. La vista pública no mostró teléfono, correo, domicilio u horario. El logotipo entregado por el usuario se utiliza en todos los portales; las fotografías adicionales quedan pendientes de obtener como archivos reutilizables.

## Migración de avisos de operador

db/operador_revision_avisos.sql crea la tabla con RLS y funciones acotadas para reportar desde un turno activo, asignar la revisión administrativa y marcar como atendidos los avisos al registrar la reparación. No permite escribir directamente en la tabla desde el navegador.
