package com.maisondumiracle.maison_du_miracle

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.StatFs
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
 *
 * Et, depuis #236, la place libre sur le disque : `dart:io` ne l'expose pas, et
 * un canal de méthode coûte moins qu'une dépendance pour une seule mesure.
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISK_SPACE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "freeBytes" -> freeBytes(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Les octets libres **là où l'application écrit** : `filesDir`, c'est-à-dire
     * le bac à sable interne, celui qui porte aussi bien les enseignements
     * téléchargés que les médias de la messagerie. Mesurer « le disque » (le
     * stockage externe, une carte SD) n'aurait aucun rapport avec l'endroit où
     * l'écriture va échouer.
     *
     * `availableBytes` et non `freeBytes` : le second compte les blocs réservés
     * au système, que l'application n'obtiendra pas — un pré-check qui laisse
     * passer en croyant mesurer est pire que pas de pré-check du tout.
     *
     * En cas d'échec on rend une **erreur**, jamais `0` : côté Dart l'erreur
     * devient « inconnu » et le pré-check laisse passer, alors que `0` dirait
     * « disque plein » et bloquerait tout téléchargement.
     */
    private fun freeBytes(result: MethodChannel.Result) {
        try {
            result.success(StatFs(filesDir.absolutePath).availableBytes)
        } catch (error: IllegalArgumentException) {
            result.error("statfs", error.message, null)
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
        const val DISK_SPACE_CHANNEL = "com.maisondumiracle.maison_du_miracle/disk_space"
        const val POST_NOTIFICATIONS_REQUEST_CODE = 1039
    }
}
