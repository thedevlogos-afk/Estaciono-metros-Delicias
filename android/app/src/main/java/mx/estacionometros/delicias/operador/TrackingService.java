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
 static final String CHANNEL="turno",ALERT="reportes";LocationManager manager;ScheduledExecutorService jobs;volatile Location latest;long lastSent;Set<String> notified=new HashSet<>();
 @Override public void onCreate(){super.onCreate();NotificationManager nm=getSystemService(NotificationManager.class);nm.createNotificationChannel(new NotificationChannel(CHANNEL,"Turno y ubicación",NotificationManager.IMPORTANCE_LOW));nm.createNotificationChannel(new NotificationChannel(ALERT,"Reportes asignados",NotificationManager.IMPORTANCE_HIGH));}
 @Override public int onStartCommand(Intent intent,int flags,int id){
  if(intent!=null&&"CERRAR".equals(intent.getAction())){if(jobs!=null)jobs.execute(()->{try{Session.call("/rest/v1/rpc/turno_operador","POST","{\"p_accion\":\"cerrar\"}",null);stopSelf();}catch(Exception e){notice("No se pudo cerrar. Abre la app y reintenta con conexión.");}});return START_NOT_STICKY;}
  if(Session.access==null||checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED){stopSelf();return START_NOT_STICKY;}
  startForeground(1,notification("Turno activo · buscando ubicación precisa"),ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION);
  if(jobs!=null)return START_NOT_STICKY;
  manager=(LocationManager)getSystemService(LOCATION_SERVICE);for(String provider:Arrays.asList(LocationManager.GPS_PROVIDER,LocationManager.NETWORK_PROVIDER))try{manager.requestLocationUpdates(provider,10000,0,this);}catch(Exception ignored){}
  jobs=Executors.newSingleThreadScheduledExecutor();jobs.scheduleWithFixedDelay(this::tick,0,25,TimeUnit.SECONDS);return START_NOT_STICKY;
 }
 void tick(){try{
  JSONArray turns=new JSONArray(Session.call("/rest/v1/turnos?select=id&fin=is.null&operador_id=eq."+Session.user,"GET",null,null));if(turns.length()==0){stopSelf();return;}
  Location l=latest;long age=l==null?Long.MAX_VALUE:(SystemClock.elapsedRealtimeNanos()-l.getElapsedRealtimeNanos())/1000000;
  if(l!=null&&age<30000&&l.getElapsedRealtimeNanos()>lastSent&&l.hasAccuracy()){
   Session.call("/rest/v1/rpc/ubicacion_operador","POST",new JSONObject().put("p_lat",l.getLatitude()).put("p_lng",l.getLongitude()).put("p_precision",l.getAccuracy()).toString(),null);lastSent=l.getElapsedRealtimeNanos();notice("Ubicación enviada · precisión "+Math.round(l.getAccuracy())+" m");
  }else notice("Sin posición reciente · revisa GPS y cielo abierto");
  JSONArray alerts=new JSONArray(Session.call("/rest/v1/alertas?select=id&leida=eq.false&inspector_id=eq."+Session.user+"&order=creado.desc&limit=50","GET",null,null));
  for(int i=0;i<alerts.length();i++){String key=alerts.getJSONObject(i).getString("id");if(notified.add(key)){Notification n=new Notification.Builder(this,ALERT).setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle("Reporte asignado").setContentText("Abre Operador Delicias para verificarlo.").setContentIntent(open()).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build();getSystemService(NotificationManager.class).notify(key.hashCode(),n);}}
 }catch(Exception e){notice("Sin envío · revisa conexión o inicia sesión nuevamente");}}
 PendingIntent open(){return PendingIntent.getActivity(this,0,new Intent(this,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);}
 Notification notification(String text){PendingIntent stop=PendingIntent.getService(this,1,new Intent(this,TrackingService.class).setAction("CERRAR"),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);return new Notification.Builder(this,CHANNEL).setSmallIcon(android.R.drawable.ic_menu_mylocation).setContentTitle("Operador Delicias · turno activo").setContentText(text).setContentIntent(open()).setOngoing(true).setOnlyAlertOnce(true).setVisibility(Notification.VISIBILITY_PRIVATE).addAction(new Notification.Action.Builder(null,"Cerrar turno",stop).build()).build();}
 void notice(String text){getSystemService(NotificationManager.class).notify(1,notification(text));}
 @Override public void onLocationChanged(Location l){latest=new Location(l);}
 @Override public void onProviderDisabled(String p){latest=null;notice("Ubicación desactivada en el teléfono");}
 @Override public void onDestroy(){if(manager!=null)manager.removeUpdates(this);if(jobs!=null)jobs.shutdownNow();latest=null;stopForeground(STOP_FOREGROUND_REMOVE);super.onDestroy();}
 @Override public IBinder onBind(Intent i){return null;}
}
