export function operationMetrics(reports=[],repairs=[]){
 const valid=reports.filter(r=>r.creado&&Number.isFinite(Date.parse(r.creado)));
 const durations=valid.filter(r=>r.verificado&&Date.parse(r.verificado)>=Date.parse(r.creado)).map(r=>(Date.parse(r.verificado)-Date.parse(r.creado))/60000);
 const failures=new Map();valid.forEach(r=>failures.set(r.parquimetro_id,(failures.get(r.parquimetro_id)||0)+1));
 return {reports:valid.length,pending:valid.filter(r=>r.estatus==='pendiente').length,verified:durations.length,averageMinutes:durations.length?durations.reduce((a,b)=>a+b,0)/durations.length:null,repairs:repairs.length,recurring:[...failures].filter(([,n])=>n>1).sort((a,b)=>b[1]-a[1])};
}
