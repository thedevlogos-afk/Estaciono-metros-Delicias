package mx.estacionometros.delicias.operador;
import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.*;
import android.location.*;
import android.os.*;
import org.json.*;
import java.util.*;
import java.util.concurrent.*;

public class TrackingService extends Service implements LocationListener {
 static final String CHANNEL="turno",ALERT="reportes";LocationManager manager;ScheduledExecutorService jobs;volatile Location latest;long lastSent,lastTurnCheck,lastAlertCheck;Set<String> notified=new HashSet<>();
 @Override public void onCreate(){super.onCreate();NotificationManager nm=getSystemService(NotificationManager.class);nm.createNotificationChannel(new NotificationChannel(CHANNEL,"Turno y ubicación",NotificationManager.IMPORTANCE_LOW));nm.createNotificationChannel(new NotificationChannel(ALERT,"Reportes asignados",NotificationManager.IMPORTANCE_HIGH));}
 @Override public int onStartCommand(Intent intent,int flags,int id){
  if(intent!=null&&"CERRAR".equals(intent.getAction())){if(jobs!=null)jobs.execute(()->{try{Session.call("/rest/v1/rpc/turno_operador","POST","{\"p_accion\":\"cerrar\"}",null);stopSelf();}catch(Exception e){notice("No se pudo cerrar. Abre la app y reintenta con conexión.");}});return START_NOT_STICKY;}
  if(Session.access==null||checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED){stopSelf();return START_NOT_STICKY;}
  startForeground(1,notification("Turno activo · buscando ubicación precisa"),ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION);
  if(jobs!=null)return START_NOT_STICKY;
  manager=(LocationManager)getSystemService(LOCATION_SERVICE);for(String provider:Arrays.asList(LocationManager.GPS_PROVIDER,LocationManager.NETWORK_PROVIDER))try{manager.requestLocationUpdates(provider,10000,0,this);}catch(Exception ignored){}
  jobs=Executors.newSingleThreadScheduledExecutor();jobs.scheduleWithFixedDelay(this::tick,0,10,TimeUnit.SECONDS);return START_NOT_STICKY;
 }
 void tick(){try{
  long now=SystemClock.elapsedRealtime();
  if(now-lastTurnCheck>=30000){JSONArray turns=new JSONArray(Session.call("/rest/v1/turnos?select=id&fin=is.null&operador_id=eq."+Session.user,"GET",null,null));lastTurnCheck=now;if(turns.length()==0){stopSelf();return;}}
  Location l=latest;long age=l==null?Long.MAX_VALUE:(now-l.getElapsedRealtimeNanos()/1000000);
  if(l!=null&&age<25000&&l.getElapsedRealtimeNanos()>lastSent&&l.hasAccuracy()){
   Session.call("/rest/v1/rpc/ubicacion_operador","POST",new JSONObject().put("p_lat",l.getLatitude()).put("p_lng",l.getLongitude()).put("p_precision",l.getAccuracy()).toString(),null);lastSent=l.getElapsedRealtimeNanos();String quality=l.getAccuracy()>100?"GPS actualizado · precisión baja ":"GPS actualizado · precisión ";notice(quality+Math.round(l.getAccuracy())+" m · envío cada 10 s");
  }else if(l==null||age>=25000)notice("Buscando GPS · última posición vencida; revisa cielo abierto");
  if(now-lastAlertCheck>=20000){JSONArray alerts=new JSONArray(Session.call("/rest/v1/alertas?select=id&leida=eq.false&inspector_id=eq."+Session.user+"&order=creado.desc&limit=50","GET",null,null));lastAlertCheck=now;
   for(int i=0;i<alerts.length();i++){String key=alerts.getJSONObject(i).getString("id");if(notified.add(key)){Notification n=new Notification.Builder(this,ALERT).setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle("Reporte asignado").setContentText("Abre Operador Delicias para verificarlo.").setContentIntent(open()).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build();getSystemService(NotificationManager.class).notify(key.hashCode(),n);}}
  }
 }catch(Exception e){notice("Sin conexión · se reintenta el envío GPS en 10 s");}}
 PendingIntent open(){return PendingIntent.getActivity(this,0,new Intent(this,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);}
 Notification notification(String text){PendingIntent stop=PendingIntent.getService(this,1,new Intent(this,TrackingService.class).setAction("CERRAR"),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);return new Notification.Builder(this,CHANNEL).setSmallIcon(android.R.drawable.ic_menu_mylocation).setContentTitle("Operador Delicias · turno activo").setContentText(text).setContentIntent(open()).setOngoing(true).setOnlyAlertOnce(true).setVisibility(Notification.VISIBILITY_PRIVATE).addAction(new Notification.Action.Builder(null,"Cerrar turno",stop).build()).build();}
 void notice(String text){getSystemService(NotificationManager.class).notify(1,notification(text));}
 @Override public void onLocationChanged(Location l){Location current=latest;long age=current==null?Long.MAX_VALUE:(SystemClock.elapsedRealtimeNanos()-current.getElapsedRealtimeNanos())/1000000;boolean better=current==null||age>15000||(l.hasAccuracy()&&(!current.hasAccuracy()||l.getAccuracy()<current.getAccuracy()));if(better)latest=new Location(l);}
 @Override public void onProviderDisabled(String p){if(LocationManager.GPS_PROVIDER.equals(p)){latest=null;notice("GPS desactivado en el teléfono");}}
 @Override public void onDestroy(){if(manager!=null)manager.removeUpdates(this);if(jobs!=null)jobs.shutdownNow();latest=null;stopForeground(STOP_FOREGROUND_REMOVE);super.onDestroy();}
 @Override public IBinder onBind(Intent i){return null;}
}
