import {isNative} from './native.js';
import {rpc,busy} from './core.js';
import {firebaseConfig} from './firebase-config.js';
let registration;
function bytes(s){return Uint8Array.from(atob(s.replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0));}
export function setupPush(){
 const host=document.getElementById('push-controls');if(!host)return;
 if(isNative()){host.innerHTML='<h3>Avisos Android</h3><p>Los permisos se solicitan al iniciar turno. Mientras está activo, el servicio consulta reportes cada 25 segundos. El push Firebase estará disponible al habilitar la identidad de envío del servidor.</p><button id="push-test" class="secondary">Probar aviso Firebase</button><p id="push-status" role="status"></p>';document.getElementById('push-test').onclick=async()=>{try{const cfg=await(await fetch('/api/push/config',{cache:'no-store'})).json();if(!cfg.nativeEnabled)throw new Error('Envío Firebase nativo pendiente de habilitar en el servidor. Las alertas del turno se siguen consultando.');const n=await rpc('probar_push');document.getElementById('push-status').textContent=n?'Prueba encolada.':'Sin dispositivo registrado. Vuelve a iniciar sesión.';}catch(e){document.getElementById('push-status').textContent=e.message;}};return;}
 host.innerHTML='<h3>Avisos de operación</h3><p>Recibe alertas aunque esta página esté en segundo plano. El sistema operativo puede silenciarlas; revisa también la bandeja de reportes. En iPhone instala primero la app en Inicio.</p><div class="actions"><button id="push-on">Activar avisos</button><button id="push-test" class="secondary">Probar aviso</button><button id="push-off" class="secondary">Desactivar aquí</button></div><p id="push-status" role="status" class="statusline">Activa los avisos en cada dispositivo que uses.</p>';
 const status=t=>document.getElementById('push-status').textContent=t;
 const run=(id,fn)=>document.getElementById(id).onclick=e=>busy(e.currentTarget,async()=>{try{await fn();}catch(er){status(er.message);}});
 run('push-on',async()=>{
  if(!('Notification'in window)||!('PushManager'in window)||!('serviceWorker'in navigator))throw new Error('Este navegador no admite avisos push. Usa Chrome o una PWA instalada compatible.');
  const permission=await Notification.requestPermission();if(permission!=='granted')throw new Error('Avisos no autorizados. Puedes habilitarlos en los ajustes del sitio.');
  const response=await fetch('/api/push/config',{cache:'no-store'});if(!response.ok)throw new Error('No se pudo consultar la configuración de avisos.');const cfg=await response.json();if(!cfg.enabled)throw new Error('El servicio de avisos todavía no está configurado.');
  await navigator.serviceWorker.register('/sw.js');registration=await navigator.serviceWorker.ready;
  let sub=await registration.pushManager.getSubscription();
  if(!sub)sub=await registration.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:bytes(cfg.publicKey)});
  const json=sub.toJSON();await rpc('registrar_push',{p_endpoint:json.endpoint,p_p256dh:json.keys.p256dh,p_auth:json.keys.auth});
  status('Avisos activados en este dispositivo.');
  // FCM registra esta instalación con el proyecto municipal; Web Push mantiene interoperabilidad con Safari/Firefox.
  try{const [{initializeApp},{getMessaging,getToken,isSupported}]=await Promise.all([import('https://www.gstatic.com/firebasejs/13.3.0/firebase-app.js'),import('https://www.gstatic.com/firebasejs/13.3.0/firebase-messaging.js')]);if(await isSupported())await getToken(getMessaging(initializeApp(firebaseConfig)),{vapidKey:cfg.publicKey,serviceWorkerRegistration:registration});}catch{status('Web Push activado. Registro complementario de Firebase pendiente; los avisos siguen disponibles.');}
 });
 run('push-test',async()=>{const n=await rpc('probar_push');status(n?'Prueba encolada. Revisa las notificaciones del dispositivo.':'Primero activa los avisos en este dispositivo.');});
 run('push-off',async()=>{registration=await navigator.serviceWorker.getRegistration('/');const sub=await registration?.pushManager.getSubscription();if(sub){await rpc('desactivar_push',{p_endpoint:sub.endpoint});await sub.unsubscribe();}status('Avisos desactivados en este dispositivo.');});
}
export async function detachPush(){const registration=await navigator.serviceWorker?.getRegistration('/');const sub=await registration?.pushManager.getSubscription();if(sub)await rpc('desactivar_push',{p_endpoint:sub.endpoint});}
