// Verifica autenticación y permiso real sin entregar una notificación.
import {accessToken} from '../lib/fcm.js';
if(!process.env.FIREBASE_SERVICE_ACCOUNT)throw new Error('Falta identidad FCM de producción');
const token=await accessToken();
const response=await fetch('https://fcm.googleapis.com/v1/projects/estacionometros-delicias/messages:send',{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({validate_only:true,message:{topic:'verificacion-operacion',data:{check:'configuracion'}}}),signal:AbortSignal.timeout(12000)});
if(!response.ok)throw new Error('Verificación FCM rechazada: HTTP '+response.status);
console.log('FCM: autenticación y permiso de envío verificados; validación sin entrega.');
