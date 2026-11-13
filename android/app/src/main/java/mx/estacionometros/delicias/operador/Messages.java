package mx.estacionometros.delicias.operador;
import android.app.*;
import android.content.*;
import com.google.firebase.messaging.*;

// Native FCM registration is scoped to the authenticated operator; never log registration tokens.
public class Messages extends FirebaseMessagingService {
 static volatile String token;
 @Override public void onNewToken(String value){token=value;enroll();}
 static void enroll(){if(token==null||Session.user==null)return;new Thread(()->{try{Session.call("/rest/v1/rpc/registrar_push_nativo","POST",new org.json.JSONObject().put("p_token",token).toString(),null);}catch(Exception ignored){}}).start();}
 @Override public void onMessageReceived(RemoteMessage message){if(Session.user==null)return;NotificationManager nm=getSystemService(NotificationManager.class);nm.createNotificationChannel(new NotificationChannel("reportes","Reportes asignados",NotificationManager.IMPORTANCE_HIGH));PendingIntent open=PendingIntent.getActivity(this,0,new Intent(this,MainActivity.class),PendingIntent.FLAG_IMMUTABLE);nm.notify(2,new Notification.Builder(this,"reportes").setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle("Estacionómetros Delicias").setContentText("Tienes una actualización. Abre la app para revisarla.").setContentIntent(open).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build());}
}
