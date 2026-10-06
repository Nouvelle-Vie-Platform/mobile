#!/usr/bin/env bash
# Lance l'app sur une cible choisie automatiquement — appelé par `make ios`, `make android`
# et `make ipad`.
#
#   tool/run_on.sh ios       un simulateur iOS : celui qui tourne déjà, sinon le premier iPhone
#                            disponible (démarré au passage)
#   tool/run_on.sh android   un émulateur Android : celui qui tourne déjà, sinon le premier AVD
#                            (démarré au passage)
#   tool/run_on.sh ipad      l'iPad physique branché (câble ou réseau)
#
# Variables :
#   IOS_SIMULATOR     nom ou UDID d'un simulateur précis (sinon : choix automatique)
#   ANDROID_EMULATOR  id d'un AVD précis (sinon : choix automatique)
#   DART_DEFINES      les --dart-define passés à `flutter run` (le Makefile les fournit)
#   FLUTTER_ARGS      arguments en plus pour `flutter run` (ex. --release)
#   DRY_RUN=1         dit ce qui serait choisi et lancé, sans rien démarrer
#
# Pourquoi un script plutôt que la recette du Makefile : le choix demande des boucles d'attente,
# des messages d'erreur utiles et un mode « à blanc », illisibles dans une recette `make`.

set -euo pipefail

cible="${1:-}"
dry="${DRY_RUN:-0}"

dire() { printf '%s\n' "$*"; }
echec() { printf '✗ %s\n' "$*" >&2; exit 1; }
faire() {
  if [ "$dry" = "1" ]; then dire "  (à blanc) $*"; else "$@"; fi
}

lancer_app() {
  local id="$1"
  # shellcheck disable=SC2086 # DART_DEFINES et FLUTTER_ARGS sont des listes d'arguments.
  faire flutter run ${DART_DEFINES:-} ${FLUTTER_ARGS:-} -d "$id"
}

# ---------------------------------------------------------------------------------------------
# iOS : simulateur
# ---------------------------------------------------------------------------------------------
cible_ios() {
  command -v xcrun >/dev/null || echec "xcrun introuvable : Xcode est-il installé ?"
  local id=""

  if [ -n "${IOS_SIMULATOR:-}" ]; then
    # Un nom ou un UDID donné : on le cherche parmi les simulateurs disponibles.
    id=$(xcrun simctl list devices available \
      | grep -F -- "$IOS_SIMULATOR" | grep -oE '[0-9A-F-]{36}' | head -1 || true)
    [ -n "$id" ] || echec "simulateur « $IOS_SIMULATOR » introuvable (voir : xcrun simctl list devices available)"
  else
    # D'abord un simulateur déjà démarré, iPhone de préférence.
    id=$(xcrun simctl list devices booted | grep -E 'iPhone' | grep -oE '[0-9A-F-]{36}' | head -1 || true)
    [ -n "$id" ] || id=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1 || true)
    # Sinon le premier iPhone disponible.
    [ -n "$id" ] || id=$(xcrun simctl list devices available \
      | grep -E '^\s+iPhone' | grep -oE '[0-9A-F-]{36}' | head -1 || true)
    [ -n "$id" ] || echec "aucun simulateur iPhone disponible (Xcode › Settings › Platforms : installer un runtime iOS)"
  fi

  local nom
  nom=$(xcrun simctl list devices | grep -F "$id" | sed -E 's/^ *//; s/ \([0-9A-F-]{36}\).*//' | head -1)
  dire "▶ Simulateur iOS : $nom ($id)"

  if ! xcrun simctl list devices booted | grep -qF "$id"; then
    dire "⏳ Démarrage du simulateur…"
    faire xcrun simctl boot "$id"
  fi
  faire open -a Simulator
  dire "⏳ Attente de la fin du démarrage…"
  faire xcrun simctl bootstatus "$id" -b
  dire "🚀 Lancement de l'app…"
  lancer_app "$id"
}

# ---------------------------------------------------------------------------------------------
# Android : émulateur
# ---------------------------------------------------------------------------------------------
emulateur_en_marche() {
  local liste
  liste=$(adb devices 2>/dev/null || true)
  printf '%s\n' "$liste" | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }'
}

cible_android() {
  command -v adb >/dev/null || echec "adb introuvable : le SDK Android est-il dans le PATH ?"
  local serie avd
  serie=$(emulateur_en_marche || true)

  if [ -z "$serie" ]; then
    if [ -n "${ANDROID_EMULATOR:-}" ]; then
      avd="$ANDROID_EMULATOR"
    else
      # Le premier émulateur Android que connaît Flutter (colonne Plateforme = android).
      # Sortie lue en entier AVANT d'être filtrée : un `awk … exit` en bout de tube fermerait
      # le tube pendant que flutter écrit encore, et `pipefail` ferait mourir le script en silence.
      local liste
      liste=$(flutter emulators 2>/dev/null || true)
      avd=$(printf '%s\n' "$liste" \
        | awk -F' • ' '$4 ~ /android/ { gsub(/[ \t]+$/, "", $1); print $1; exit }')
    fi
    [ -n "$avd" ] || echec "aucun émulateur Android (créer un AVD : flutter emulators --create)"

    dire "▶ Émulateur Android : $avd (démarrage)"
    faire flutter emulators --launch "$avd"

    if [ "$dry" != "1" ]; then
      dire "⏳ Attente de l'émulateur…"
      local essais=0
      until serie=$(emulateur_en_marche) && [ -n "$serie" ]; do
        essais=$((essais + 1))
        [ "$essais" -le 90 ] || echec "l'émulateur n'est pas apparu en 3 minutes"
        sleep 2
      done
      dire "⏳ Attente de la fin du démarrage d'Android…"
      essais=0
      until [ "$(adb -s "$serie" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
        essais=$((essais + 1))
        [ "$essais" -le 90 ] || echec "Android n'a pas fini de démarrer en 3 minutes"
        sleep 2
      done
    else
      serie="emulator-XXXX"
    fi
  else
    dire "▶ Émulateur Android déjà en marche : $serie"
  fi

  dire "🚀 Lancement de l'app…"
  lancer_app "$serie"
}

# ---------------------------------------------------------------------------------------------
# iPad physique
# ---------------------------------------------------------------------------------------------
cible_ipad() {
  command -v jq >/dev/null || echec "jq introuvable (brew install jq)"
  dire "▶ Recherche d'un iPad branché…"
  local appareils id nom
  appareils=$(flutter devices --machine 2>/dev/null || echo '[]')
  id=$(printf '%s' "$appareils" | jq -r '
    map(select(.targetPlatform == "ios" and (.emulator | not) and (.name | test("ipad"; "i"))))
    | .[0].id // empty')
  if [ -z "$id" ]; then
    echec "aucun iPad détecté. Brancher l'iPad (ou le même réseau Wi-Fi), le déverrouiller, accepter « Faire confiance à cet ordinateur », activer le mode développeur (Réglages › Confidentialité et sécurité), puis : flutter devices"
  fi
  nom=$(printf '%s' "$appareils" | jq -r --arg id "$id" 'map(select(.id == $id)) | .[0].name')
  dire "▶ iPad : $nom ($id)"
  dire "🚀 Lancement de l'app…"
  lancer_app "$id"
}

case "$cible" in
  ios) cible_ios ;;
  android) cible_android ;;
  ipad) cible_ipad ;;
  *) echec "usage : tool/run_on.sh ios|android|ipad" ;;
esac
