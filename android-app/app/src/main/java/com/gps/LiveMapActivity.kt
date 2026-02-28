package com.gps

import android.os.Bundle
import android.webkit.WebView
import androidx.appcompat.app.AppCompatActivity

class LiveMapActivity : AppCompatActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_map)

    val webView = findViewById<WebView>(R.id.webview)
    webView.settings.javaScriptEnabled = true;
    val html = """
      <html>
        <head>
          <script src="https://cesium.com/downloads/cesiumjs/releases/1.102/Build/Cesium/Cesium.js"></script>
        </head>
        <body>
          <div id="cesiumContainer" style="height:100vh"></div>
          <script>
            Cesium.Ion.defaultAccessToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiI1NzhmZTZlNy1mNDMwLTQwZWMtOWQ0Ny1kNTM3ZTZkZGY3NDkiLCJpZCI6Mzk1NTI5LCJpYXQiOjE3NzIyMTg3MjF9.KJuxvYyw7CSPNvOzmpFUGYNzeWxN-e-WOnOuikGRKZs';
            var viewer = new Cesium.Viewer('cesiumContainer');
          </script>
        </body>
      </html>
    """.trimIndent()
    webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null);
  }
}
