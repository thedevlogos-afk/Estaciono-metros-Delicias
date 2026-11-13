import {sendNative} from '../../lib/fcm.js';
import webpush from 'web-push';
import crypto from 'node:crypto';
const BASE='https://jawtbygyawivolwudpax.supabase.co';
const KEY='sb_publishable__dFXTrjmFzsHavJNGe596A_Y8-YETPV';
export const config={maxDuration:60};
export function allowedEndpoint(endpoint){try{const u=new URL(endpoint);return u.protocol==='https:'&&!u.username&&!u.password&&(!u.port||u.port==='443')&&(['fcm.googleapis.com','updates.push.services.mozilla.com','web.push.apple.com'].includes(u.hostname)||u.hostname.endsWith('.notify.windows.com'));}catch{return false;}}
async function rpc(name,body){const r=await fetch(BASE+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:KEY,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(10000)});if(!r.ok)throw new Error('Database dispatcher error');return r.json();}
export default async function handler(req,res){
 res.setHeader('Cache-Control','no-store');if(req.method!=='POST')return res.status(405).end();
 const expected=process.env.PUSH_DISPATCH_KEY||'',provided=(req.headers.authorization||'').replace(/^Bearer /,'');
 if(!expected||Buffer.byteLength(provided)!==Buffer.byteLength(expected)||!crypto.timingSafeEqual(Buffer.from(provided),Buffer.from(expected)))return res.status(401).json({error:'No autorizado'});
 if(!process.env.VAPID_PUBLIC_KEY||!process.env.VAPID_PRIVATE_KEY)return res.status(503).json({error:'Push no configurado'});
 webpush.setVapidDetails('https://estacionometros-delicias.vercel.app',process.env.VAPID_PUBLIC_KEY,process.env.VAPID_PRIVATE_KEY);
 try{const jobs=await rpc('push_reclamar',{p_key:expected});let sent=0,failed=0;
 for(let i=0;i<jobs.length;i+=5){await Promise.all(jobs.slice(i,i+5).map(async j=>{let ok=false,invalid=false,error='';try{if(j.tipo==='android'){await sendNative(j);}else{if(!allowedEndpoint(j.endpoint)){invalid=true;throw new Error('endpoint_rechazado');}await webpush.sendNotification({endpoint:j.endpoint,keys:{p256dh:j.p256dh,auth:j.auth}},JSON.stringify({title:j.titulo,body:j.cuerpo,url:j.ruta,tag:j.evento}),{TTL:900,urgency:'high',timeout:12000});}ok=true;sent++;}catch(e){invalid=invalid||[404,410].includes(e.statusCode);error=String(e.statusCode||e.code||'envio_fallido');failed++;}await rpc('push_resultado',{p_key:expected,p_id:j.id,p_ok:ok,p_invalido:invalid,p_error:error});}));}
 return res.json({sent,failed,claimed:jobs.length});
 }catch{return res.status(503).json({error:'No se pudo procesar la cola; se reintentará.'});}
}
