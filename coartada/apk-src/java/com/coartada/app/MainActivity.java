package com.coartada.app;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Iterator;

/**
 * Coartada: el juego es una página web empaquetada en assets/www y mostrada en un WebView.
 * El puente "CoartadaNative" solo ofrece peticiones HTTPS a api.anthropic.com para el Detective IA.
 */
public class MainActivity extends Activity {
    private static final String INICIO = "file:///android_asset/www/index.html";
    private static final String API = "https://api.anthropic.com/";
    private WebView web;

    @Override
    @SuppressLint("SetJavaScriptEnabled")
    protected void onCreate(Bundle estado) {
        super.onCreate(estado);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        web = new WebView(this);
        web.setBackgroundColor(0xFF14110F);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowContentAccess(false);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setTextZoom(100);
        web.setOverScrollMode(WebView.OVER_SCROLL_NEVER);
        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
                Uri u = r.getUrl();
                if (u.toString().startsWith("file:///android_asset/")) return false;
                // Cualquier enlace externo se abre fuera de la app: el WebView solo muestra el juego.
                try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (Exception e) { /* sin navegador */ }
                return true;
            }
        });
        web.addJavascriptInterface(new Puente(), "CoartadaNative");
        setContentView(web);
        if (estado == null) web.loadUrl(INICIO); else web.restoreState(estado);
    }

    @Override
    protected void onSaveInstanceState(Bundle salida) {
        super.onSaveInstanceState(salida);
        web.saveState(salida);
    }

    @Override
    public void onBackPressed() {
        web.evaluateJavascript("(window.__coartadaAtras && window.__coartadaAtras()) ? '1' : '0'", new android.webkit.ValueCallback<String>() {
            @Override
            public void onReceiveValue(String v) {
                if (v == null || !v.contains("1")) finish();
            }
        });
    }

    @Override
    protected void onDestroy() {
        if (web != null) web.destroy();
        super.onDestroy();
    }

    private void responder(final String id, final int status, final String cabeceras, final String cuerpo) {
        final String js = "window.__coartadaHttp(" + JSONObject.quote(id) + "," + status + "," + cabeceras + "," + JSONObject.quote(cuerpo) + ")";
        runOnUiThread(new Runnable() {
            @Override
            public void run() { web.evaluateJavascript(js, null); }
        });
    }

    private static String leer(InputStream in) throws Exception {
        if (in == null) return "";
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) > 0) b.write(buf, 0, n);
        in.close();
        return b.toString("UTF-8");
    }

    private class Puente {
        @JavascriptInterface
        public void http(final String id, final String url, final String metodo, final String cabecerasJson, final String cuerpo) {
            new Thread(new Runnable() {
                @Override
                public void run() {
                    HttpURLConnection c = null;
                    try {
                        if (!url.startsWith(API)) throw new SecurityException("Destino no permitido");
                        c = (HttpURLConnection) new URL(url).openConnection();
                        c.setInstanceFollowRedirects(false);
                        c.setConnectTimeout(20000);
                        c.setReadTimeout(180000);
                        c.setRequestMethod(metodo);
                        JSONObject cab = new JSONObject(cabecerasJson);
                        for (Iterator<String> it = cab.keys(); it.hasNext(); ) {
                            String k = it.next();
                            c.setRequestProperty(k, cab.getString(k));
                        }
                        if (cuerpo != null && cuerpo.length() > 0) {
                            c.setDoOutput(true);
                            OutputStream o = c.getOutputStream();
                            o.write(cuerpo.getBytes("UTF-8"));
                            o.close();
                        }
                        int status = c.getResponseCode();
                        String texto = leer(status >= 400 ? c.getErrorStream() : c.getInputStream());
                        JSONObject salida = new JSONObject();
                        String[] utiles = {"content-type", "request-id", "retry-after", "x-should-retry"};
                        for (String k : utiles) {
                            String v = c.getHeaderField(k);
                            if (v != null) salida.put(k, v);
                        }
                        responder(id, status, salida.toString(), texto);
                    } catch (Exception e) {
                        responder(id, 0, "{}", "Sin conexión");
                    } finally {
                        if (c != null) c.disconnect();
                    }
                }
            }).start();
        }
    }
}
