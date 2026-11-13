import {esc,date,money} from './core.js';

const numberFormat=new Intl.NumberFormat('es-MX');
const stateLabels={
 operativo:'Operativo',
 falla_reportada:'Falla reportada',
 falla_confirmada:'Falla confirmada',
 mantenimiento:'En mantenimiento'
};
const stateClasses={
 operativo:'state-ok',
 falla_reportada:'state-review',
 falla_confirmada:'state-fault',
 mantenimiento:'state-service'
};
let selectedDays=7,selectedZone='all',selectedStatus='all',searchText='';

function stateOf(m){return stateLabels[m.estado]?m.estado:'operativo';}
function zoneOf(m){return m.zona===null||m.zona===undefined||m.zona===''?'Sin zona':String(m.zona);}
function formatCount(value){return numberFormat.format(Number(value)||0);}
function shortDate(value){return new Date(value).toLocaleDateString('es-MX',{day:'2-digit',month:'short'});}
function matchesMeter(m,term){
 if(!term)return true;
 const text=[m.id,m.calle,zoneOf(m)].join(' ').toLocaleLowerCase('es-MX');
 return text.includes(term.toLocaleLowerCase('es-MX'));
}
function meterMatchesById(meters,id,term){
 if(!term)return true;
 const m=meters.find(x=>String(x.id)===String(id));
 return m?matchesMeter(m,term):String(id||'').toLocaleLowerCase('es-MX').includes(term.toLocaleLowerCase('es-MX'));
}
function metricCard(tone,label,value,note,nav){
 const icons={
  'Parquímetros activos':'<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="2.5" width="10" height="16" rx="2"></rect><path d="M9.5 6h5M10 10h4M9 18.5v3M15 18.5v3M7 21.5h10"></path></svg>',
  'En operación':'<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"></circle><path d="m8 12 2.5 2.5L16 9"></path></svg>',
  'Reportes por verificar':'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 3.5h8l4 4v13H6z"></path><path d="M14 3.5v5h4M9 13h6M9 16.5h4"></path></svg>',
  'GPS reciente':'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 1 1 14 0Z"></path><circle cx="12" cy="10" r="2.3"></circle></svg>',
  'Incidencias de aparatos':'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 22 20H2L12 3Z"></path><path d="M12 9v5M12 17.5h.01"></path></svg>',
  'Buzón por atender':'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5.5h16v12H9l-5 3v-15Z"></path><path d="M8 9h8M8 13h5"></path></svg>'
 };
 return '<button type="button" class="metric-card tone-'+tone+'" data-nav="'+nav+'"><span class="metric-card__head"><span class="metric-card__icon">'+(icons[label]||'')+'</span><span class="metric-card__label">'+esc(label)+'</span></span><strong>'+esc(value)+'</strong><span class="metric-card__note">'+esc(note)+'</span><span class="metric-card__action">Abrir detalle</span></button>';
}
function statusBadge(state){
 return '<span class="status-badge '+(stateClasses[state]||'state-ok')+'"><i></i>'+esc(stateLabels[state]||state)+'</span>';
}
function chartBuckets(rows,field,days){
 const now=Date.now(),start=now-days*86400000,count=7,span=(now-start)/count;
 const buckets=Array.from({length:count},(_,i)=>({label:shortDate(new Date(start+i*span)),value:0}));
 if(days===1)buckets.forEach((b,i)=>b.label=new Date(start+i*span).toLocaleTimeString('es-MX',{hour:'2-digit',minute:undefined}));
 rows.forEach(row=>{
  const stamp=new Date(row[field]||0).getTime();
  if(stamp<start||stamp>now)return;
  const index=Math.min(count-1,Math.max(0,Math.floor((stamp-start)/span)));
  buckets[index].value++;
 });
 return buckets;
}
function barsMarkup(rows,field,days){
 const buckets=chartBuckets(rows,field,days),max=Math.max(1,...buckets.map(x=>x.value));
 return '<div class="chart-columns" role="img" aria-label="Actividad distribuida en siete intervalos del periodo"><div class="chart-columns__grid">'+buckets.map(b=>'<div class="chart-column" title="'+esc(b.label+': '+b.value)+'"><span class="chart-column__value">'+formatCount(b.value)+'</span><div class="chart-column__track"><i style="height:'+Math.max(b.value?8:2,b.value/max*100)+'%"></i></div><small>'+esc(b.label)+'</small></div>').join('')+'</div></div>';
}
function listRow(label,value,tone){
 return '<div class="status-row"><span><i class="legend-dot '+tone+'"></i>'+esc(label)+'</span><strong>'+formatCount(value)+'</strong></div>';
}
function eventCard(item){
 return '<article class="activity-row"><span class="activity-mark '+esc(item.tone)+'"></span><div class="activity-copy"><b>'+esc(item.title)+'</b><p>'+esc(item.detail)+'</p></div><time>'+esc(date(item.time))+'</time></article>';
}

export async function renderAdminDashboard({api,goTo}){
 const since90=new Date(Date.now()-90*86400000).toISOString();
 const [meters,profiles,reports,inbox,turns,notices,tickets,maintenance]=await Promise.all([
  api('/rest/v1/parquimetros?select=*&order=id'),
  api('/rest/v1/perfiles?select=user_id,nombre,rol,activo,lat,lng,precision_m,ubicacion_at&order=nombre'),
  api('/rest/v1/reportes?select=id,folio,parquimetro_id,falla,estatus,gracia_hasta,creado,verificado&creado=gte.'+encodeURIComponent(since90)+'&order=creado.desc&limit=1000'),
  api('/rest/v1/buzon?select=id,folio,categoria,estatus,creado&order=creado.desc&limit=1000'),
  api('/rest/v1/turnos?select=operador_id&fin=is.null'),
  api('/rest/v1/avisos_aparato?select=id,estatus,parquimetro_id,motivo,creado,detalle&estatus=neq.atendido&order=creado.desc&limit=100'),
  api('/rest/v1/multas?select=folio,monto,estatus,fecha,parquimetro_id&fecha=gte.'+encodeURIComponent(since90)+'&order=fecha.desc&limit=1000'),
  api('/rest/v1/mantenimiento?select=id,parquimetro_id,nota,creado&order=creado.desc&limit=100')
 ]);
 const activeMeters=meters.filter(m=>m.activo!==false);
 const zones=Array.from(new Set(activeMeters.map(zoneOf))).sort((a,b)=>a.localeCompare(b,'es-MX',{numeric:true}));
 const turnIds=new Set(turns.map(t=>String(t.operador_id)));
 const staff=profiles.filter(p=>p.rol==='inspector'&&p.activo);
 const now=Date.now();
 const gpsState=p=>{
  if(!turnIds.has(String(p.user_id))||!p.ubicacion_at||p.lat===null||p.lng===null)return 'sin posicion';
  const age=now-new Date(p.ubicacion_at).getTime();
  const precision=Number(p.precision_m);
  if(age<=25000&&Number.isFinite(precision)&&precision<=100)return 'reciente';
  if(age<=60000)return 'demorado';
  return 'sin senal';
 };
 const freshStaff=staff.filter(p=>gpsState(p)==='reciente');
 const delayedStaff=staff.filter(p=>gpsState(p)==='demorado');
 const onTurnStaff=staff.filter(p=>turnIds.has(String(p.user_id)));
 const lostStaff=onTurnStaff.filter(p=>gpsState(p)==='sin senal');
 const view=document.getElementById('view');

 function render(){
  const term=searchText.trim();
  const scopedMeters=activeMeters.filter(m=>(selectedZone==='all'||zoneOf(m)===selectedZone)&&matchesMeter(m,term));
  const filteredMeters=scopedMeters.filter(m=>selectedStatus==='all'||stateOf(m)===selectedStatus);
  const start=Date.now()-selectedDays*86400000;
  const reportsInRange=reports.filter(r=>new Date(r.creado).getTime()>=start&&(selectedZone==='all'||zoneOf(activeMeters.find(m=>String(m.id)===String(r.parquimetro_id))||{})===selectedZone)&&meterMatchesById(activeMeters,r.parquimetro_id,term));
  const ticketsInRange=tickets.filter(t=>new Date(t.fecha).getTime()>=start&&(selectedZone==='all'||zoneOf(activeMeters.find(m=>String(m.id)===String(t.parquimetro_id))||{})===selectedZone)&&meterMatchesById(activeMeters,t.parquimetro_id,term));
  const countState=state=>scopedMeters.filter(m=>stateOf(m)===state).length;
  const failedCount=countState('falla_reportada')+countState('falla_confirmada')+countState('mantenimiento');
  const pendingReports=reportsInRange.filter(r=>r.estatus==='pendiente');
  const inboxInRange=inbox.filter(item=>item.estatus!=='cerrado'&&new Date(item.creado).getTime()>=start);
  const ticketAmount=ticketsInRange.reduce((sum,t)=>sum+Number(t.monto||0),0);
  const ticketCount=ticketsInRange.length;
  const donutTotal=scopedMeters.length;
  const pctOperative=donutTotal?countState('operativo')/donutTotal*100:0;
  const pctReported=donutTotal?(countState('operativo')+countState('falla_reportada'))/donutTotal*100:0;
  const pctConfirmed=donutTotal?(countState('operativo')+countState('falla_reportada')+countState('falla_confirmada'))/donutTotal*100:0;
  const donutStyle=donutTotal
   ?'background:conic-gradient(#15966b 0 '+pctOperative+'%,#e7a128 '+pctOperative+'% '+pctReported+'%,#d84d59 '+pctReported+'% '+pctConfirmed+'%,#8091a8 '+pctConfirmed+'% 100%)'
   :'background:#e5ebf3';
  const groupedZones={};
  scopedMeters.forEach(m=>{
   const z=zoneOf(m);
   if(!groupedZones[z])groupedZones[z]={total:0,active:0};
   groupedZones[z].total++;
   if(stateOf(m)==='operativo')groupedZones[z].active++;
  });
  const zoneRows=Object.entries(groupedZones).map(([name,v])=>({name,total:v.total,active:v.active})).sort((a,b)=>b.total-a.total).slice(0,6);
  const zoneMax=Math.max(1,...zoneRows.map(z=>z.total));
  const activity=[];
  reportsInRange.forEach(r=>activity.push({time:r.creado,title:'Reporte ciudadano · '+(r.folio||'sin folio'),detail:'Parquímetro '+r.parquimetro_id+' · '+r.falla,tone:r.estatus==='pendiente'?'activity-warn':'activity-blue'}));
  inboxInRange.forEach(item=>activity.push({time:item.creado,title:'Buzón ciudadano · '+item.categoria,detail:item.folio+' · '+(item.estatus==='en_revision'?'En revisión':'Recibido'),tone:'activity-violet'}));
  notices.forEach(n=>activity.push({time:n.creado,title:'Aviso de campo · '+n.parquimetro_id,detail:n.motivo,tone:'activity-warn'}));
  maintenance.forEach(m=>activity.push({time:m.creado,title:'Intervención registrada · '+m.parquimetro_id,detail:m.nota,tone:'activity-green'}));
  ticketsInRange.forEach(t=>activity.push({time:t.fecha,title:'Ticket emitido · '+t.folio,detail:'Parquímetro '+t.parquimetro_id+' · '+money(t.monto),tone:'activity-blue'}));
  activity.sort((a,b)=>new Date(b.time)-new Date(a.time));
  const priorityMeters=scopedMeters.filter(m=>stateOf(m)!=='operativo');
  const shownMeters=filteredMeters.slice(0,12);
  const gpsCoverage=onTurnStaff.length?Math.round(freshStaff.length/onTurnStaff.length*100):0;

  view.innerHTML=
   '<div class="admin-dashboard">'+
    '<section class="dashboard-heading"><div><p class="eyebrow">Centro de control · Delicias</p><h2>Resumen operativo</h2><p class="muted">Estado de aparatos, atención ciudadana, personal de campo y actividad del periodo.</p></div><div class="dashboard-live"><span class="live-indicator"></span><div><b>Datos de operación</b><small>Actualización automática cada 15 s</small></div></div></section>'+
    '<form id="dashboard-filters" class="dashboard-filters">'+
     '<label>Periodo<select id="dashboard-days"><option value="1">Últimas 24 horas</option><option value="7">Últimos 7 días</option><option value="30">Últimos 30 días</option><option value="90">Últimos 90 días</option></select></label>'+
     '<label>Zona<select id="dashboard-zone"><option value="all">Todas las zonas</option>'+zones.map(z=>'<option value="'+esc(z)+'">'+esc(z==='Sin zona'?z:'Zona '+z)+'</option>').join('')+'</select></label>'+
     '<label>Estado en la tabla<select id="dashboard-status"><option value="all">Todos los estados</option><option value="operativo">Operativo</option><option value="falla_reportada">Falla reportada</option><option value="falla_confirmada">Falla confirmada</option><option value="mantenimiento">En mantenimiento</option></select></label>'+
     '<label class="dashboard-search">Buscar aparato<input id="dashboard-search" type="search" placeholder="ID, calle o zona" value="'+esc(searchText)+'"></label>'+
     '<button type="submit" class="secondary dashboard-filter-button">Aplicar</button>'+
     '<button type="button" id="dashboard-clear" class="quiet-button">Limpiar filtros</button>'+
    '</form>'+
    '<section class="dashboard-kpis" aria-label="Indicadores del periodo">'+
     metricCard('blue','Parquímetros activos',formatCount(scopedMeters.length),formatCount(scopedMeters.filter(m=>m.lat!==null&&m.lng!==null).length)+' con coordenadas','aparatos')+
     metricCard('green','En operación',formatCount(countState('operativo')),donutTotal?Math.round(pctOperative)+'% del padrón filtrado':'Sin aparatos en este filtro','aparatos')+
     metricCard('amber','Reportes por verificar',formatCount(pendingReports.length),reportsInRange.length+' reportes en el periodo','reportes')+
     metricCard('violet','GPS reciente',formatCount(freshStaff.length),formatCount(delayedStaff.length)+' con demora · '+formatCount(lostStaff.length)+' sin señal reciente','mapa')+
     metricCard('red','Incidencias de aparatos',formatCount(failedCount),formatCount(notices.length)+' avisos de campo abiertos','mantenimiento')+
     metricCard('violet','Buzón por atender',formatCount(inboxInRange.length),'Quejas y sugerencias abiertas','buzon')+
    '</section>'+
    '<section class="dashboard-grid dashboard-grid--top">'+
     '<article class="dashboard-panel"><div class="panel-heading"><div><span class="panel-kicker">Estado de la red</span><h3>Condición de los parquímetros</h3></div><button type="button" class="link-button" data-nav="aparatos">Ver padrón</button></div>'+
      '<div class="status-summary"><div class="status-donut" style="'+donutStyle+'"><div><strong>'+formatCount(donutTotal)+'</strong><small>aparatos</small></div></div><div class="status-breakdown">'+
       listRow('Operativos',countState('operativo'),'dot-green')+listRow('Falla reportada',countState('falla_reportada'),'dot-amber')+listRow('Falla confirmada',countState('falla_confirmada'),'dot-red')+listRow('Mantenimiento',countState('mantenimiento'),'dot-slate')+
      '</div></div><p class="panel-footnote">'+formatCount(scopedMeters.filter(m=>m.lat!==null&&m.lng!==null).length)+' de '+formatCount(donutTotal)+' aparatos tienen coordenadas registradas.</p></article>'+
     '<article class="dashboard-panel"><div class="panel-heading"><div><span class="panel-kicker">Atención ciudadana</span><h3>Reportes recibidos</h3></div><span class="panel-period">'+esc(selectedDays===1?'24 h':selectedDays+' días')+'</span></div>'+
      barsMarkup(reportsInRange,'creado',selectedDays)+
      '<div class="mini-stats"><div><strong>'+formatCount(pendingReports.length)+'</strong><span>Pendientes</span></div><div><strong>'+formatCount(reportsInRange.filter(r=>r.estatus==='procedente').length)+'</strong><span>Falla confirmada</span></div><div><strong>'+formatCount(reportsInRange.filter(r=>r.estatus==='improcedente').length)+'</strong><span>No confirmados</span></div></div>'+
      '<button type="button" class="panel-action" data-nav="reportes">Abrir bandeja de reportes</button></article>'+
     '<article class="dashboard-panel"><div class="panel-heading"><div><span class="panel-kicker">Cobertura territorial</span><h3>Aparatos por zona</h3></div><span class="panel-period">Padrón filtrado</span></div>'+
      (zoneRows.length?'<div class="zone-chart">'+zoneRows.map(z=>'<div class="zone-row"><div class="zone-row__label"><span>'+esc(z.name==='Sin zona'?z.name:'Zona '+z.name)+'</span><b>'+formatCount(z.total)+'</b></div><div class="zone-row__track"><i style="width:'+Math.max(2,z.total/zoneMax*100)+'%"></i></div><small>'+formatCount(z.active)+' operativos</small></div>').join('')+'</div>':'<div class="empty-state">No hay aparatos para los filtros seleccionados.</div>')+
      '<button type="button" class="panel-action" data-nav="mapa">Abrir mapa operativo</button></article>'+
    '</section>'+
    '<section class="dashboard-grid dashboard-grid--lower">'+
     '<article class="dashboard-panel"><div class="panel-heading"><div><span class="panel-kicker">Actividad administrativa</span><h3>Tickets emitidos</h3></div><button type="button" class="link-button" data-nav="multas">Ver analítica</button></div>'+
      barsMarkup(ticketsInRange,'fecha',selectedDays)+
      '<div class="ticket-summary"><div><small>Importe emitido</small><strong>'+money(ticketAmount)+'</strong></div><div><small>Tickets</small><strong>'+formatCount(ticketCount)+'</strong></div></div>'+
      '<p class="panel-footnote">Las tarifas siguen pendientes de autorización. Este dato refleja únicamente tickets existentes en la base.</p></article>'+
     '<article class="dashboard-panel"><div class="panel-heading"><div><span class="panel-kicker">Personal de campo</span><h3>Señal y ubicación</h3></div><button type="button" class="link-button" data-nav="mapa">Ver mapa</button></div>'+
      '<div class="gps-overview"><div class="gps-ring" style="--gps-progress:'+gpsCoverage+'%"><span><strong>'+gpsCoverage+'%</strong><small>GPS reciente</small></span></div><div class="gps-counts">'+listRow('En turno · posición reciente',freshStaff.length,'dot-green')+listRow('Actualización demorada',delayedStaff.length,'dot-amber')+listRow('Sin señal o posición',lostStaff.length,'dot-slate')+'<p class="panel-footnote">La posición se considera reciente si llegó en los últimos 25 s y tiene precisión de hasta 100 m.</p></div></div>'+
      '<button type="button" class="panel-action" data-nav="equipo">Revisar equipo</button></article>'+
    '</section>'+
    '<section class="dashboard-grid dashboard-grid--bottom">'+
     '<article class="dashboard-panel dashboard-panel--wide"><div class="panel-heading"><div><span class="panel-kicker">Inventario y estado</span><h3>Parquímetros</h3></div><span class="result-count">Mostrando '+formatCount(shownMeters.length)+' de '+formatCount(filteredMeters.length)+'</span></div>'+
      (shownMeters.length?'<div class="table-wrap dashboard-table-wrap"><table class="dashboard-table"><thead><tr><th>Aparato</th><th>Zona</th><th>Estado</th><th>Coordenadas</th><th>Acceso</th></tr></thead><tbody>'+shownMeters.map(m=>'<tr><td><strong>'+esc(m.id)+'</strong><small>'+esc(m.calle||'Sin calle registrada')+'</small></td><td>'+esc(zoneOf(m))+'</td><td>'+statusBadge(stateOf(m))+'</td><td>'+(m.lat!==null&&m.lng!==null?'Registradas':'Pendientes')+'</td><td><button type="button" class="table-action" data-nav="mapa">Ver mapa</button></td></tr>').join('')+'</tbody></table></div>':'<div class="empty-state">No se encontraron aparatos con estos filtros.</div>')+
      '<div class="table-footer"><span>Los estados reflejan el padrón y los reportes registrados; no son telemetría del mecanismo.</span><button type="button" class="link-button" data-nav="aparatos">Abrir padrón completo</button></div></article>'+
     '<article class="dashboard-panel"><div class="panel-heading"><div><span class="panel-kicker">Seguimiento</span><h3>Actividad reciente</h3></div><button type="button" class="link-button" data-nav="auditoria">Bitácora</button></div>'+
      (activity.length?'<div class="activity-list">'+activity.slice(0,6).map(eventCard).join('')+'</div>':'<div class="empty-state">Sin actividad en el periodo seleccionado.</div>')+
      '<div class="priority-summary"><div><span class="priority-mark"></span><div><b>'+formatCount(priorityMeters.length)+' aparatos requieren seguimiento</b><small>Fallas reportadas, confirmadas o en mantenimiento.</small></div></div><button type="button" class="secondary" data-nav="mantenimiento">Ver mantenimiento</button></div></article>'+
    '</section>'+
   '</div>';

  document.getElementById('dashboard-days').value=String(selectedDays);
  document.getElementById('dashboard-zone').value=selectedZone;
  document.getElementById('dashboard-status').value=selectedStatus;
  document.getElementById('dashboard-filters').onsubmit=e=>{e.preventDefault();searchText=document.getElementById('dashboard-search').value;render();};
  document.getElementById('dashboard-days').onchange=e=>{selectedDays=Number(e.target.value)||7;render();};
  document.getElementById('dashboard-zone').onchange=e=>{selectedZone=e.target.value;render();};
  document.getElementById('dashboard-status').onchange=e=>{selectedStatus=e.target.value;render();};
  document.getElementById('dashboard-clear').onclick=()=>{selectedDays=7;selectedZone='all';selectedStatus='all';searchText='';render();};
  view.querySelectorAll('[data-nav]').forEach(button=>button.onclick=()=>goTo(button.dataset.nav));
 }
 render();
}
