package mx.estacionometros.delicias.operador;
import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.*;
import android.webkit.*;
import android.location.LocationManager;
import androidx.webkit.*;
import org.json.*;
import java.util.*;
import java.util.concurrent.*;
import com.google.firebase.*;

public class MainActivity extends Activity {
 static final String ORIGIN="https://estacionometros-delicias.vercel.app";
 WebView web; ExecutorService worker=Executors.newSingleThreadExecutor(); JavaScriptReplyProxy permissionReply;String permissionId;
 @Override public void onCreate(Bundle saved){super.onCreate(saved);
  if(FirebaseApp.getApps(this).isEmpty())FirebaseApp.initializeApp(this,new FirebaseOptions.Builder().setApplicationId("1:869388930451:android:38a0153b8d1f2f5d446c66").setProjectId("estacionometros-delicias").setGcmSenderId("869388930451").setApiKey("AIzaSyBwxQxgWp50eFapX3k8sfnF0JOggVrx6TI").build());
  web=new WebView(this);setContentView(web);web.getSettings().setJavaScriptEnabled(true);web.getSettings().setDomStorageEnabled(true);web.getSettings().setAllowFileAccess(false);web.getSettings().setAllowContentAccess(false);web.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
  web.setWebViewClient(new WebViewClient(){@Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){Uri u=r.getUrl();if("https".equals(u.getScheme())&&"estacionometros-delicias.vercel.app".equals(u.getHost())&&u.getPort()==-1)return false;if(r.isForMainFrame()&&("https".equals(u.getScheme())||"mailto".equals(u.getScheme())))try{startActivity(new Intent(Intent.ACTION_VIEW,u));}catch(Exception ignored){}return true;}});
  if(!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)){new AlertDialog.Builder(this).setMessage("Actualiza Android System WebView para usar esta aplicación.").setPositiveButton("Cerrar",(d,w)->finish()).show();return;}
  WebViewCompat.addWebMessageListener(web,"NativeOps",Collections.singleton(ORIGIN),(view,message,source,main,reply)->{if(!main||!ORIGIN.equals(source.toString()))return;try{JSONObject m=new JSONObject(message.getData());String id=m.getString("id"),action=m.getString("action");JSONObject data=m.optJSONObject("data");if(action.equals("prepare")){permissionReply=reply;permissionId=id;ArrayList<String> p=new ArrayList<>();p.add(Manifest.permission.ACCESS_FINE_LOCATION);p.add(Manifest.permission.ACCESS_COARSE_LOCATION);if(Build.VERSION.SDK_INT>=33)p.add(Manifest.permission.POST_NOTIFICATIONS);requestPermissions(p.toArray(new String[0]),21);return;}worker.execute(()->{try{Object result=true;switch(action){case "session":Session.set(data);com.google.firebase.messaging.FirebaseMessaging.getInstance().getToken().addOnSuccessListener(t->{Messages.token=t;Messages.enroll();});break;case "clear":if(Messages.token!=null)try{Session.call("/rest/v1/rpc/desactivar_push_nativo","POST",new JSONObject().put("p_token",Messages.token).toString(),null);}catch(Exception ignored){}stopService(new Intent(this,TrackingService.class));Session.clear();break;case "start":runOnUiThread(()->{try{startForegroundService(new Intent(this,TrackingService.class));answer(reply,id,true,null);}catch(Exception e){answer(reply,id,null,"No se pudo iniciar ubicación. Mantén la app visible e intenta otra vez.");}});return;case "stop":stopService(new Intent(this,TrackingService.class));break;case "request":String path=data.getString("path"),method=data.optString("method","GET");if(!path.startsWith("/rest/v1/")||path.contains("..")||!(method.equals("GET")||method.equals("POST")||method.equals("PATCH")))throw new Exception("Solicitud no permitida");String raw=Session.call(path,method,data.isNull("body")?null:data.optString("body",null),data.optString("prefer",null));result=new JSONTokener(raw).nextValue();break;default:throw new Exception("Acción no permitida");}answer(reply,id,result,null);}catch(Exception e){answer(reply,id,null,e.getMessage());}});}catch(Exception ignored){}});
  web.setOnApplyWindowInsetsListener((v,insets)->{v.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());return insets;});
  if(Build.VERSION.SDK_INT>=33)getOnBackInvokedDispatcher().registerOnBackInvokedCallback(android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT,()->back());
  web.loadUrl(ORIGIN+"/panel");
 }
 void answer(JavaScriptReplyProxy r,String id,Object value,String error){runOnUiThread(()->{try{r.postMessage(new JSONObject().put("id",id).put("value",value==null?JSONObject.NULL:value).put("error",error==null?JSONObject.NULL:error).toString());}catch(Exception ignored){}});}
 @Override public void onRequestPermissionsResult(int request,String[] p,int[] grants){super.onRequestPermissionsResult(request,p,grants);if(request!=21||permissionReply==null)return;boolean fine=checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED;boolean notifications=Build.VERSION.SDK_INT<33||checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED;LocationManager lm=(LocationManager)getSystemService(LOCATION_SERVICE);String err=!fine?"Activa ubicación precisa en los permisos de la app.":!notifications?"Activa notificaciones para ver el turno y sus avisos.":!lm.isLocationEnabled()?"Activa la ubicación del teléfono e intenta nuevamente.":null;answer(permissionReply,permissionId,true,err);permissionReply=null;}
 @android.annotation.SuppressLint("GestureBackNavigation")
 @Override public void onBackPressed(){back();}
 void back(){if(web.canGoBack())web.goBack();else moveTaskToBack(true);}
 @Override public void onDestroy(){worker.shutdown();web.destroy();super.onDestroy();}
}
