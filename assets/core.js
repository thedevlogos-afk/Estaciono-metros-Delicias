export const SB='https://jawtbygyawivolwudpax.supabase.co';
export const KEY='sb_publishable__dFXTrjmFzsHavJNGe596A_Y8-YETPV';
export const $=id=>document.getElementById(id);
export const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export const money=n=>new Intl.NumberFormat('es-MX',{style:'currency',currency:'MXN'}).format(n||0);
export const date=s=>s?new Date(s).toLocaleString('es-MX',{timeZone:'America/Chihuahua'}):'Sin registro';
let session=null;
export async function api(path,options={}){
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
 try{const [p]=await api('/rest/v1/perfiles?select=*&user_id=eq.'+s.user.id);if(!p?.activo||(role==='admin'&&p.rol!=='admin'))throw new Error('Esta cuenta no tiene acceso activo a este portal.');return p;}catch(e){await logout();throw e;}
}
async function refresh(){try{const s=await request('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:JSON.stringify({refresh_token:session.refresh_token})});session={...s,expires_at:Date.now()+s.expires_in*1000};}catch(e){session=null;location.reload();throw e;}}
export async function logout(){try{if(session)await request('/auth/v1/logout',{method:'POST'});}finally{session=null;}}
export function message(id,text,error=false){const el=$(id);el.hidden=!text;el.className='message'+(error?' error':'');el.textContent=text;}
export async function busy(button,fn){button.disabled=true;try{return await fn();}finally{button.disabled=false;}}
export function setupNetwork(){const update=()=>{document.querySelectorAll('[data-network]').forEach(el=>el.textContent=navigator.onLine?'Con conexión':'Sin conexión · los envíos requieren internet');};addEventListener('online',update);addEventListener('offline',update);update();}
export function mountMap(id){if(!window.L)throw new Error('El mapa no pudo cargar. Usa la lista y vuelve a intentar.');const map=L.map(id).setView([28.1895,-105.4715],16);L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'}).addTo(map);return map;}
export function setupPWA(){if('serviceWorker'in navigator)navigator.serviceWorker.register('/sw.js').catch(()=>{});}
