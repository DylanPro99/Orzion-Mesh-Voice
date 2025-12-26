
package com.orzion.mesh

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class MeshForegroundService : Service() {
    
    companion object {
        const val CHANNEL_ID = "orzion_mesh_channel"
        const val NOTIFICATION_ID = 1
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // El servicio mantiene BLE/WiFi activos mientras la app está minimizada
        return START_STICKY // Se reinicia automáticamente si el sistema lo mata
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Orzion Mesh Network",
                NotificationManager.IMPORTANCE_LOW // Silencioso
            ).apply {
                description = "Mantiene tu nodo activo en la red de malla"
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 
            0, 
            intent, 
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Orzion Mesh Activo")
            .setContentText("Tu nodo está retransmitiendo mensajes")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true) // No se puede deslizar para cerrar
            .build()
    }
}
package com.orzion.mesh

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class MeshForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "mesh_service_channel"
        private const val NOTIFICATION_ID = 1
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Orzion Mesh Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantiene el nodo de malla activo"
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Orzion Mesh")
            .setContentText("Nodo activo - retransmitiendo mensajes")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
