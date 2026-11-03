export default async function handler(req,res){
 if(req.method!=='POST')return res.status(405).end();
 const {folio,placa,email}=req.body||{},S=process.env.SUPABASE_URL,K=process.env.SUPABASE_ANON_KEY;
 const r=await fetch(`${S}/rest/v1/rpc/consultar_multa`,{method:'POST',headers:{apikey:K,Authorization:'Bearer '+K,'Content-Type':'application/json'},body:JSON.stringify({p_folio:folio,p_placa:placa})});
 const [m]=await r.json();
 if(!m)return res.status(404).json({error:'No se encontró la multa con ese folio y placa.'});
 if(m.estatus==='pagada')return res.status(409).json({error:'Esta multa ya fue pagada.'});
 const o=process.env.SITE_URL,p=new URLSearchParams({mode:'payment','success_url':o+'/?pagado=1','cancel_url':o+'/#pagar',customer_email:email,
  'line_items[0][quantity]':'1','line_items[0][price_data][currency]':'mxn','line_items[0][price_data][unit_amount]':String(Math.round(m.monto*100)),
  'line_items[0][price_data][product_data][name]':'Multa de parquímetro '+m.folio,'metadata[folio]':m.folio,'payment_intent_data[receipt_email]':email});
 const s=await(await fetch('https://api.stripe.com/v1/checkout/sessions',{method:'POST',headers:{Authorization:'Bearer '+process.env.STRIPE_SECRET_KEY,'Content-Type':'application/x-www-form-urlencoded'},body:p})).json();
 res.status(s.url?200:500).json(s.url?{url:s.url}:{error:'No se pudo iniciar el pago.'});
}
