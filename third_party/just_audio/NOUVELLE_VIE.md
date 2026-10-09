# just_audio 0.10.6 — copie modifiée pour Nouvelle Vie

Copie **intégrale** de `just_audio` 0.10.6 (pub.dev, licence `LICENSE`
inchangée), branchée par `dependency_overrides` dans le `pubspec.yaml` de
l'application. Seul le dossier `darwin/just_audio/.swiftpm/` (données Xcode
locales) n'a pas été copié.

## Pourquoi

Le direct aligné sur l'écoute (mobile#187, plan
`server-portal/docs/radio-direct-aligne-plan.md`) a besoin de **l'heure
d'antenne de ce qu'on entend** : l'`EXT-X-PROGRAM-DATE-TIME` (PDT) que
liquidsoap écrit sur chaque segment. just_audio 0.10.6 ne l'expose pas, et
l'identifiant du lecteur natif (`_id`) est privé en Dart : impossible de
l'ajouter de l'extérieur. Un dépôt de plus pour un fork aurait coûté plus cher
qu'une copie relue dans la même PR.

## Ce qui a changé — trois fichiers, rien d'autre

Une méthode : `getProgramTime`, sur le canal existant du lecteur
(`com.ryanheise.just_audio.methods.<id>`), qui rend des **millisecondes depuis
l'époque** (`int`) ou `null`.

| Fichier | Lignes (copie) | Ce qui est ajouté |
| --- | --- | --- |
| `android/src/main/java/com/ryanheise/just_audio/AudioPlayer.java` | 553-555, 569-579 | `case "getProgramTime"` dans `onMethodCall`, et `getProgramTime()` : `windowStartTimeMs + getCurrentPosition()` de la fenêtre courante ; `null` si la timeline est vide ou si `windowStartTimeMs == C.TIME_UNSET` (pas de PDT) |
| `darwin/just_audio/Sources/just_audio/AudioPlayer.m` | 183-187 | branche `getProgramTime` dans `handleMethodCall` : `_player.currentItem.currentDate` en ms ; `nil` → `null` |
| `lib/just_audio.dart` | 1304-1314 | `Future<int?> AudioPlayer.programTimeMs()` : `null` sur le web, après `dispose`, ou sur le lecteur inactif ; sinon appel du canal avec l'identifiant de la plateforme courante (`platform.id`) |

Côté application, un seul appelant : `JustAudioContentPlayer.heardTime()`
(`lib/data/players/just_audio_content_player.dart`).

## Monter de version

1. Remplacer le dossier par la nouvelle version, telle que publiée
   (`~/.pub-cache/hosted/pub.dev/just_audio-<version>/`, sans `.swiftpm/`).
2. Rejouer le diff ci-dessous depuis `third_party/just_audio/` :

   ```sh
   sed -n '/^```diff$/,/^```$/p' NOUVELLE_VIE.md | sed '1d;$d' | patch -p1
   ```

   S'il ne s'applique plus, refaire les trois ajouts à la main — ils sont
   petits — et mettre à jour les lignes du tableau.
3. Vérifier que le paquet n'expose pas désormais l'heure de programme
   lui-même : si oui, supprimer cette copie et l'override.
4. Sur appareil (Android **et** iOS), avec un flux portant le PDT : l'heure
   entendue doit suivre l'heure du VPS moins le retard d'écoute (~24 s).

```diff
--- a/android/src/main/java/com/ryanheise/just_audio/AudioPlayer.java
+++ b/android/src/main/java/com/ryanheise/just_audio/AudioPlayer.java
@@ -550,6 +550,9 @@
                 equalizerBandSetGain(call.argument("bandIndex"), call.argument("gain"));
                 result.success(new HashMap<String, Object>());
                 break;
+            case "getProgramTime": // Nouvelle Vie : voir NOUVELLE_VIE.md
+                result.success(getProgramTime());
+                break;
             default:
                 result.notImplemented();
                 break;
@@ -563,6 +566,17 @@
         } finally {
             broadcastPendingPlaybackEvent();
         }
+    }
+
+    // Nouvelle Vie : l'heure de programme (EXT-X-PROGRAM-DATE-TIME) de ce
+    // qu'on entend, en ms depuis l'époque ; null sans PDT ou sans média.
+    private Long getProgramTime() {
+        Timeline timeline = player.getCurrentTimeline();
+        if (timeline.isEmpty()) return null;
+        Timeline.Window window = timeline.getWindow(
+                player.getCurrentMediaItemIndex(), new Timeline.Window());
+        if (window.windowStartTimeMs == C.TIME_UNSET) return null;
+        return window.windowStartTimeMs + player.getCurrentPosition();
     }
 
     private ShuffleOrder decodeShuffleOrder(List<Integer> indexList) {
--- a/darwin/just_audio/Sources/just_audio/AudioPlayer.m
+++ b/darwin/just_audio/Sources/just_audio/AudioPlayer.m
@@ -180,6 +180,11 @@
             result(@{});
         } else if ([@"setAndroidAudioAttributes" isEqualToString:call.method]) {
             result(@{});
+        } else if ([@"getProgramTime" isEqualToString:call.method]) {
+            // Nouvelle Vie : voir NOUVELLE_VIE.md. L'heure de programme
+            // (EXT-X-PROGRAM-DATE-TIME) de ce qu'on entend, en ms ; nil sinon.
+            NSDate *date = _player.currentItem.currentDate;
+            result(date == nil ? nil : @((long long)(date.timeIntervalSince1970 * 1000.0)));
         } else {
             result(FlutterMethodNotImplemented);
         }
--- a/lib/just_audio.dart
+++ b/lib/just_audio.dart
@@ -1301,6 +1301,17 @@
             allowsExternalPlayback: allowsExternalPlayback));
   }
 
+  /// Nouvelle Vie (voir NOUVELLE_VIE.md) : the program date-time
+  /// (EXT-X-PROGRAM-DATE-TIME) of what is being heard, in ms since the epoch,
+  /// or `null` without one (no PDT, no media, idle player, web).
+  Future<int?> programTimeMs() async {
+    if (kIsWeb || _disposed) return null;
+    final platform = await _platform;
+    if (platform is _IdleAudioPlayer) return null;
+    return MethodChannel('com.ryanheise.just_audio.methods.${platform.id}')
+        .invokeMethod<int>('getProgramTime');
+  }
+
   /// Seeks to a particular [position], and optionally to a particular [index]
   /// within [sequence].
   ///
```
