import {esc} from './core.js';
const memory=new Map();
export function enhanceAdminModule(page){
 if(['resumen','mapa'].includes(page))return;
 const view=document.getElementById('view');
 const items=[...view.querySelectorAll('.list > article, tbody > tr')];
 const states=[...new Set(items.map(row=>row.querySelector('.pill,select[data-mail]')?.textContent.trim()).filter(Boolean))];
 // Select controls expose only their selected state.
 const statusOf=row=>row.querySelector('select[data-mail]')?.value||row.querySelector('.pill')?.textContent.trim()||'';
 const groups=[...new Set(items.map(statusOf).filter(Boolean))];
 const state=memory.get(page)||{query:'',status:''};memory.set(page,state);
 const tools=document.createElement('section');tools.className='module-tools';
 tools.innerHTML='<div class="module-metrics"><button class="module-summary active" data-filter=""><strong>'+items.length+'</strong><span>Registros consultados</span></button>'+groups.map(s=>'<button class="module-summary" data-filter="'+esc(s)+'"><strong>'+items.filter(row=>statusOf(row)===s).length+'</strong><span>'+esc(s.replaceAll('_',' '))+'</span></button>').join('')+'</div><div class="module-filter"><label>Buscar en este módulo<input type="search" placeholder="Folio, aparato, persona o descripción" value="'+esc(state.query)+'"></label><button class="secondary module-reset">Restablecer filtros</button><output aria-live="polite"></output></div>';
 view.prepend(tools);
 const update=()=>{let count=0;items.forEach(row=>{const show=(!state.query||row.textContent.toLocaleLowerCase('es-MX').includes(state.query.toLocaleLowerCase('es-MX')))&&(!state.status||statusOf(row)===state.status);row.hidden=!show;if(show)count++;});tools.querySelector('output').textContent=count+' de '+items.length+' registros';tools.querySelectorAll('[data-filter]').forEach(b=>b.classList.toggle('active',b.dataset.filter===state.status));};
 tools.querySelector('input').oninput=e=>{state.query=e.target.value;update();};tools.querySelectorAll('[data-filter]').forEach(b=>b.onclick=()=>{state.status=b.dataset.filter;update();});tools.querySelector('.module-reset').onclick=()=>{state.query='';state.status='';tools.querySelector('input').value='';update();};
 items.filter(row=>row.tagName==='ARTICLE').forEach((article,index)=>{article.classList.add('module-record');const title=article.querySelector('h3,b');if(!title)return;const details=document.createElement('details');details.className='module-record-details';const summary=document.createElement('summary');summary.textContent='Ver información y acciones';details.append(summary);[...article.children].filter(child=>child!==title&&!child.classList.contains('pill')&&child.tagName!=='H3').forEach(child=>details.append(child));article.append(details);});
 view.querySelectorAll('table').forEach(table=>{table.querySelectorAll('th').forEach((th,column)=>{const button=document.createElement('button');button.className='table-sort';button.textContent=th.textContent+' ↕';th.replaceChildren(button);let direction=1;button.onclick=()=>{const body=table.tBodies[0];[...body.rows].sort((a,b)=>direction*a.cells[column].textContent.localeCompare(b.cells[column].textContent,'es-MX',{numeric:true})).forEach(row=>body.append(row));direction*=-1;};});});
 update();
}
