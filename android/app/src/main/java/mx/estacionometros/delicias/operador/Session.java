package mx.estacionometros.delicias.operador;
import org.json.*;
import java.net.*;
import java.io.*;
import java.nio.charset.StandardCharsets;

// Session lives only in process memory. Closing/force-stopping the process requires sign-in again.
final class Session {
 static String access,refresh,user; static long expires;
 static final String BASE="https://jawtbygyawivolwudpax.supabase.co";
 static final String KEY="sb_publishable__dFXTrjmFzsHavJNGe596A_Y8-YETPV";
 static synchronized void set(JSONObject s)throws Exception {access=s.getString("access_token");refresh=s.getString("refresh_token");expires=s.optLong("expires_at",System.currentTimeMillis()+3500000);user=s.getJSONObject("user").getString("id");}
 static synchronized void clear(){access=null;refresh=null;user=null;expires=0;}
 static synchronized String call(String path,String method,String body,String prefer)throws Exception {
  if(access==null)throw new Exception("Inicia sesión nuevamente.");
  if(System.currentTimeMillis()>expires-60000){JSONObject s=new JSONObject(http("/auth/v1/token?grant_type=refresh_token","POST",new JSONObject().put("refresh_token",refresh).toString(),null,null));access=s.getString("access_token");refresh=s.getString("refresh_token");expires=System.currentTimeMillis()+s.getLong("expires_in")*1000;}
  return http(path,method,body,access,prefer);
 }
 static String read(InputStream stream)throws Exception{try(InputStream in=stream;ByteArrayOutputStream out=new ByteArrayOutputStream()){byte[] b=new byte[4096];int n;while((n=in.read(b))!=-1)out.write(b,0,n);return out.toString("UTF-8");}}
 static String http(String path,String method,String body,String token,String prefer)throws Exception {
  HttpURLConnection c=(HttpURLConnection)new URL(BASE+path).openConnection();c.setInstanceFollowRedirects(false);c.setConnectTimeout(12000);c.setReadTimeout(15000);c.setRequestMethod(method);c.setRequestProperty("apikey",KEY);c.setRequestProperty("Content-Type","application/json");if(token!=null)c.setRequestProperty("Authorization","Bearer "+token);if(prefer!=null)c.setRequestProperty("Prefer",prefer);
  try{if(body!=null){c.setDoOutput(true);try(OutputStream o=c.getOutputStream()){o.write(body.getBytes(StandardCharsets.UTF_8));}}int code=c.getResponseCode();InputStream stream=code>=400?c.getErrorStream():c.getInputStream();String text=stream==null?"null":read(stream);if(code>=400){String msg;try{msg=new JSONObject(text).optString("message","No se pudo completar la operación.");}catch(Exception e){msg="No se pudo completar la operación.";}throw new Exception(msg);}return text.isEmpty()?"null":text;}finally{c.disconnect();}
 }
}
