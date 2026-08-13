package com.maisondumiracle.maison_du_miracle

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `AudioServiceActivity` et non `FlutterActivity` : c'est elle qui rend le
 * `FlutterEngine` **partagé** avec le service de lecture. Sans elle, ouvrir
 * l'application depuis la notification lancerait un second moteur, et la
 * lecture en cours resterait inaccessible.
 *
 * Elle porte en plus la seule chose qu'`audio_service` ne fait pas : demander
 * `POST_NOTIFICATIONS`. Depuis Android 13, une permission déclarée au manifeste
 * ne suffit pas — sans la demande, la notification de lecture n'apparaît jamais,
 * et rien ne le signale.
 */
class MainActivity : AudioServiceActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPostNotifications" -> {
                        result.success(requestPostNotifications())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Demande la permission si elle manque. Rend `true` quand elle est déjà
     * accordée — ou quand la version d'Android ne la connaît pas, auquel cas
     * les notifications sont autorisées d'office.
     *
     * Volontairement sans rappel de résultat : la lecture ne dépend pas de la
     * réponse, seule la notification en dépend. Bloquer le démarrage sur un
     * refus priverait de son un fidèle qui a simplement dit non à une
     * notification.
     */
    private fun requestPostNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            return true
        }
        requestPermissions(arrayOf(permission), POST_NOTIFICATIONS_REQUEST_CODE)
        return false
    }

    private companion object {
        const val CHANNEL = "com.maisondumiracle.maison_du_miracle/notifications"
        const val POST_NOTIFICATIONS_REQUEST_CODE = 1039
    }
}
