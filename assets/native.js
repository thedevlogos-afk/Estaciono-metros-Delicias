const pending=new Map();
export const isNative=()=>typeof window!=='undefined'&&!!window.NativeOps;
if(isNative())window.NativeOps.onmessage=e=>{try{const m=JSON.parse(e.data),p=pending.get(m.id);if(!p)return;clearTimeout(p.timer);pending.delete(m.id);m.error?p.reject(new Error(m.error)):p.resolve(m.value);}catch{}};
export function native(action,data={}){if(!isNative())return Promise.resolve(null);return new Promise((resolve,reject)=>{const id=crypto.randomUUID(),timer=setTimeout(()=>{pending.delete(id);reject(new Error('La app no respondió. Revisa el permiso y vuelve a intentar.'));},60000);pending.set(id,{resolve,reject,timer});window.NativeOps.postMessage(JSON.stringify({id,action,data}));});}
