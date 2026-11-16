import {mountWorkOrders} from './work-orders.js';
import {esc,date} from './core.js';
import {operationMetrics} from './operations-metrics.js';
export async function mountMaintenancePlanner(page,api){
 if(page!=='mantenimiento')return;
 const [meters,reports,repairs]=await Promise.all([api('/rest/v1/parquimetros?select=id,calle&order=id'),api('/rest/v1/reportes?select=parquimetro_id,creado,verificado,estatus&order=creado.desc&limit=1000'),api('/rest/v1/mantenimiento?select=creado,parquimetro_id&order=creado.desc&limit=1000')]);
 const m=operationMetrics(reports,repairs),root=document.createElement('section');root.className='card';root.innerHTML='<h3>Análisis de atención</h3><p class="muted">Hasta 1,000 registros por fuente. Duración desde recepción hasta verificación; no representa tiempo de reparación.</p><div class="stats">'+[[m.reports,'Reportes consultados'],[m.pending,'Pendientes'],[m.averageMinutes===null?'Sin datos':Math.round(m.averageMinutes)+' min','Promedio de verificación'],[m.repairs,'Reparaciones registradas']].map(([n,t])=>'<div><b class="number">'+esc(n)+'</b><small style="display:block">'+t+'</small></div>').join('')+'</div><h3>Aparatos con reportes reiterados</h3>'+m.recurring.slice(0,10).map(([id,n])=>'<button type="button" class="secondary" data-history-meter="'+esc(id)+'">'+esc(id)+' · '+n+' reportes · Ver historial</button>').join('');
 document.getElementById('view').append(root);root.querySelectorAll('[data-history-meter]').forEach(b=>b.onclick=()=>{const select=document.getElementById('case-meter');if(select){select.value=b.dataset.historyMeter;select.dispatchEvent(new Event('change'));select.closest('section').scrollIntoView({behavior:'smooth'});}});const orders=document.createElement('section');orders.className='card';root.after(orders);await mountWorkOrders(orders,true);

}
