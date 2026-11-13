import {native,isNative} from './native.js';
export const SB='https://jawtbygyawivolwudpax.supabase.co';
export const KEY='sb_publishable__dFXTrjmFzsHavJNGe596A_Y8-YETPV';
export const $=id=>document.getElementById(id);
export const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export const money=n=>new Intl.NumberFormat('es-MX',{style:'currency',currency:'MXN'}).format(n||0);
export const date=s=>s?new Date(s).toLocaleString('es-MX',{timeZone:'America/Chihuahua'}):'Sin registro';
let session=null;
export async function api(path,options={}){
 if(session&&isNative()&&path.startsWith('/rest/v1/'))return native('request',{path,method:options.method||'GET',body:options.body||null,prefer:options.headers?.Prefer||null});
 if(session&&session.expires_at<Date.now()+60000) await refresh();
 return request(path,options);
}
async function request(path,options={}){
 const headers={apikey:KEY,'Content-Type':'application/json',...(session?{Authorization:'Bearer '+session.access_token}:{}),...options.headers};
 const r=await fetch(SB+path,{...options,headers,cache:'no-store'});
 const data=await r.json().catch(()=>null);
 if(!r.ok)throw new Error(data?.message||data?.error_description||data?.msg||'No se pudo conectar. Intenta nuevamente.');
 return data;
}
export const rpc=(name,body={})=>api('/rest/v1/rpc/'+name,{method:'POST',body:JSON.stringify(body)});
export async function login(email,password,role){
 const s=await request('/auth/v1/token?grant_type=password',{method:'POST',body:JSON.stringify({email,password})});
 session={...s,expires_at:Date.now()+s.expires_in*1000};
 try{if(isNative())await native('session',session);if(role==='admin')await rpc('activar_administrador_inicial');const [p]=await api('/rest/v1/perfiles?select=*&user_id=eq.'+s.user.id);if(!p?.activo||(role==='admin'&&p.rol!=='admin'))throw new Error('Esta cuenta no tiene acceso activo a este portal.');return p;}catch(e){await logout();throw e;}
}
async function refresh(){try{const s=await request('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:JSON.stringify({refresh_token:session.refresh_token})});session={...s,expires_at:Date.now()+s.expires_in*1000};}catch(e){session=null;location.reload();throw e;}}
export async function logout(){try{if(session)await request('/auth/v1/logout',{method:'POST'});}finally{if(isNative())await native('clear');session=null;}}
export function message(id,text,error=false){const el=$(id);el.hidden=!text;el.className='message'+(error?' error':'');el.textContent=text;}
export async function busy(button,fn){button.disabled=true;try{return await fn();}finally{button.disabled=false;}}
export function setupNetwork(){const update=()=>{document.querySelectorAll('[data-network]').forEach(el=>el.textContent=navigator.onLine?'Con conexión':'Sin conexión · los envíos requieren internet');};addEventListener('online',update);addEventListener('offline',update);update();}
export function mountMap(id){if(!window.L)throw new Error('El mapa no pudo cargar. Usa la lista y vuelve a intentar.');const map=L.map(id).setView([28.1895,-105.4715],16);L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'}).addTo(map);return map;}
const meterSvg='<svg viewBox="0 0 24 28" aria-hidden="true"><path d="M12 2.5a6.5 6.5 0 0 0-6.5 6.5v12.8h13V9A6.5 6.5 0 0 0 12 2.5Z" fill="currentColor"/><path d="M8 7h8v3H8zM9 14h6v5H9z" fill="#fff"/><path d="M4 22h16v2H4z" fill="currentColor"/></svg>';
const pawnSvg='<svg viewBox="0 0 24 28" aria-hidden="true"><circle cx="12" cy="5" r="3.2" fill="currentColor"/><path d="M9 9c0-1.1 1.2-1.8 3-1.8S15 7.9 15 9l1.1 4.1c.3 1.2-.6 2.3-1.9 2.3H9.8c-1.3 0-2.2-1.1-1.9-2.3L9 9Z" fill="currentColor"/><path d="m9 16 6 0 1.5 4.2h-9L9 16ZM5 21.2h14v2.5H5z" fill="currentColor"/></svg>';
export function meterMapIcon(state='operativo'){const cls=state==='falla'?'meter-alert':state==='mantenimiento'?'meter-maintenance':'meter-normal';const label=state==='falla'?'Parquímetro con reporte':state==='mantenimiento'?'Parquímetro en mantenimiento':'Parquímetro';return L.divIcon({className:'map-div-icon',html:`<span class="map-pin ${cls}" role="img" aria-label="${label}"><span class="map-pin__bubble">${meterSvg}</span></span>`,iconSize:[24,32],iconAnchor:[12,30],popupAnchor:[0,-28]});}
export function operatorMapIcon(state='fresh'){const cls=state==='stale'?'operator-delayed':state==='offline'?'operator-offline':state==='weak'?'operator-weak':'operator-online';const label=state==='offline'?'Operador sin señal reciente':state==='stale'?'Ubicación del operador demorada':state==='weak'?'Operador con precisión GPS baja':'Operador con GPS actualizado';return L.divIcon({className:'map-div-icon',html:`<span class="map-pin ${cls}" role="img" aria-label="${label}"><span class="map-pin__bubble">${pawnSvg}</span><i class="map-pin__status"></i></span>`,iconSize:[24,32],iconAnchor:[12,30],popupAnchor:[0,-28]});}
export function setupPWA(){if('serviceWorker'in navigator)navigator.serviceWorker.register('/sw.js').catch(()=>{});}
