
package com.orzion.mesh

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onResume() {
        super.onResume()
        
        // Iniciar servicio en primer plano para mantener el nodo activo
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(Intent(this, MeshForegroundService::class.java))
        } else {
            startService(Intent(this, MeshForegroundService::class.java))
        }
    }
}
