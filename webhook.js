import crypto from 'node:crypto';
export const config={api:{bodyParser:false}};
export default async function handler(req,res){
 const chunks=[];for await(const c of req)chunks.push(c);const raw=Buffer.concat(chunks).toString('utf8');
 const h=Object.fromEntries((req.headers['stripe-signature']||'').split(',').map(x=>x.split('=')));
 const sig=crypto.createHmac('sha256',process.env.STRIPE_WEBHOOK_SECRET).update(`${h.t}.${raw}`).digest('hex');
 if(!h.v1||h.v1.length!==sig.length||!crypto.timingSafeEqual(Buffer.from(h.v1),Buffer.from(sig)))return res.status(400).end();
 const ev=JSON.parse(raw);
 if(ev.type==='checkout.session.completed'){const s=ev.data.object,S=process.env.SUPABASE_URL,K=process.env.SUPABASE_SERVICE_ROLE_KEY,
  H={apikey:K,Authorization:'Bearer '+K,'Content-Type':'application/json',Prefer:'resolution=ignore-duplicates'};
  await fetch(`${S}/rest/v1/pagos`,{method:'POST',headers:H,body:JSON.stringify({recibo:'RC-'+Date.now().toString(36).toUpperCase(),multa_folio:s.metadata.folio,stripe_session:s.id,monto:s.amount_total/100,email:s.customer_email})});
  await fetch(`${S}/rest/v1/multas?folio=eq.${encodeURIComponent(s.metadata.folio)}`,{method:'PATCH',headers:H,body:JSON.stringify({estatus:'pagada'})});}
 res.status(200).json({ok:true});
}
