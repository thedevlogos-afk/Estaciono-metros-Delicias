import {esc,date} from './core.js';
export async function mountCaseHistory(page,api){
 if(!['reportes','mantenimiento'].includes(page))return;
 const view=document.getElementById('view');
 const [meters,reports,notices,repairs,staff]=await Promise.all([
 api('/rest/v1/parquimetros?select=id,calle,zona,estado&order=id'),
 api('/rest/v1/reportes?select=id,folio,parquimetro_id,falla,estatus,creado,verificado,nota_agente,inspector_id&order=creado.desc&limit=100'),
 api('/rest/v1/avisos_aparato?select=*&order=creado.desc&limit=100'),
 api('/rest/v1/mantenimiento?select=*&order=creado.desc&limit=100'),
 api('/rest/v1/perfiles?select=user_id,nombre&order=nombre')]);
 const section=document.createElement('section');section.className='card case-history';section.innerHTML='<h3>Expediente del parquímetro</h3><p class="muted">Historial relacionado por aparato. Hasta 100 registros por fuente; una reparación no implica el cierre de cada reporte ciudadano.</p><label>Aparato<select id="case-meter"><option value="">Selecciona un parquímetro</option>'+meters.map(m=>'<option value="'+esc(m.id)+'">'+esc(m.id+' · '+m.calle)+'</option>').join('')+'</select></label><div id="case-events" aria-live="polite"></div>';view.append(section);
 const person=id=>staff.find(p=>p.user_id===id)?.nombre||'Sin responsable registrado';
 section.querySelector('select').onchange=e=>{const id=e.target.value,events=[];
 reports.filter(r=>r.parquimetro_id===id).forEach(r=>{events.push({time:r.creado,title:'Reporte ciudadano · '+r.folio,detail:r.falla+' · '+r.estatus});if(r.verificado)events.push({time:r.verificado,title:'Verificación · '+r.folio,detail:person(r.inspector_id)+' · '+(r.nota_agente||'Sin nota')});});
 notices.filter(n=>n.parquimetro_id===id).forEach(n=>{events.push({time:n.creado,title:'Aviso de campo · '+n.estatus,detail:person(n.operador_id)+' · '+n.detalle});if(n.revisado_at)events.push({time:n.revisado_at,title:'Revisión administrativa',detail:person(n.revisado_por)});if(n.atendido_at)events.push({time:n.atendido_at,title:'Aviso atendido',detail:person(n.atendido_por)});});
 repairs.filter(r=>r.parquimetro_id===id).forEach(r=>events.push({time:r.creado,title:'Reparación registrada',detail:person(r.autor_id)+' · '+r.nota}));
 events.sort((a,b)=>new Date(b.time)-new Date(a.time));section.querySelector('#case-events').innerHTML=events.map(e=>'<article class="case-event"><small>'+esc(date(e.time))+'</small><b>'+esc(e.title)+'</b><p>'+esc(e.detail)+'</p></article>').join('')||'<p class="muted">Sin eventos en los registros consultados.</p>';
 };
}
