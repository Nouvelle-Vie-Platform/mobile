# Makefile — Maison du Miracle
# Raccourcis pour démarrer un émulateur et lancer l'app.
# Surcharge possible : make android ANDROID_EMULATOR=Pixel_7_API_34

IOS_EMULATOR     ?= apple_ios_simulator
ANDROID_EMULATOR ?= emulateur_flutter

# URL du backend, passée à l'app par --dart-define (jamais codée en dur dans
# les sources). Sur un appareil physique, viser l'IP locale du Mac :
#   make ios API_BASE_URL=http://192.168.1.20:3333
API_BASE_URL ?= https://eenv.brainsial.com

# Depuis l'émulateur Android, la machine hôte s'appelle 10.0.2.2 — `localhost`
# y désigne l'émulateur lui-même. Une valeur donnée en ligne de commande reste
# prioritaire.
ifeq ($(origin API_BASE_URL),command line)
ANDROID_API_BASE_URL := $(API_BASE_URL)
else
ANDROID_API_BASE_URL ?= http://10.0.2.2:3333
endif

DART_DEFINES         := --dart-define=API_BASE_URL=$(API_BASE_URL)
ANDROID_DART_DEFINES := --dart-define=API_BASE_URL=$(ANDROID_API_BASE_URL)

.DEFAULT_GOAL := help
.PHONY: help ios android web web-assets hls-probe devices test analyze format \
        l10n gen migrations clean

help: ## Affiche cette aide
	@echo "Maison du Miracle — cibles disponibles :"
	@echo "  make ios       Démarre le simulateur iOS + lance l'app"
	@echo "  make android   Démarre l'émulateur Android + lance l'app (JDK 17/21 requis)"
	@echo "  make web       Lance l'app dans Chrome"
	@echo "  make devices   Liste les émulateurs et appareils"
	@echo "  make test      flutter test"
	@echo "  make analyze   flutter analyze"
	@echo "  make format    dart format lib test"
	@echo "  make l10n      flutter gen-l10n"
	@echo "  make gen       Régénère le code Drift (.g.dart)"
	@echo "  make migrations  Exporte le schéma local d'une nouvelle version"
	@echo "  make web-assets  Re-télécharge sqlite3.wasm + drift_worker.js + hls.min.js"
	@echo "  make hls-probe   Prouve dans Chrome que le lecteur web joue (réseau requis)"
	@echo "  make clean     flutter clean"
	@echo ""
	@echo "URL du backend (--dart-define=API_BASE_URL) :"
	@echo "  iOS / web  $(API_BASE_URL)"
	@echo "  Android    $(ANDROID_API_BASE_URL)"
	@echo "  Surcharge  make ios API_BASE_URL=http://192.168.1.20:3333"

ios: ## Simulateur iOS + app
	@echo "▶ Démarrage du simulateur iOS ($(IOS_EMULATOR))…"
	-@flutter emulators --launch $(IOS_EMULATOR)
	@echo "⏳ Attente du simulateur…"
	@until xcrun simctl list devices booted | grep -q "Booted"; do sleep 2; done
	@echo "🚀 Lancement de l'app sur iOS…"
	@flutter run $(DART_DEFINES) -d $$(xcrun simctl list devices booted | grep -oE "[0-9A-Fa-f-]{36}" | head -1)

android: ## Émulateur Android + app (nécessite un JDK 17/21)
	@echo "▶ Démarrage de l'émulateur Android ($(ANDROID_EMULATOR))…"
	-@flutter emulators --launch $(ANDROID_EMULATOR)
	@echo "⏳ Attente de l'émulateur…"
	@until adb devices | grep -qw device; do sleep 2; done
	@echo "🚀 Lancement de l'app sur Android…"
	@flutter run $(ANDROID_DART_DEFINES) -d $$(adb devices | awk '$$2=="device"{print $$1; exit}')

web: ## Lance l'app dans Chrome
	flutter run $(DART_DEFINES) -d chrome

devices: ## Liste les émulateurs et appareils
	@flutter emulators
	@flutter devices

test: ## flutter test
	flutter test

analyze: ## flutter analyze
	flutter analyze

format: ## dart format
	dart format lib test

l10n: ## Régénère les traductions
	flutter gen-l10n

gen: ## Régénère le code Drift du magasin local (.g.dart, à versionner)
	@echo "▶ Les .g.dart sont VERSIONNÉS — la CI ne lance pas build_runner."
	dart run build_runner build

migrations: ## Exporte le schéma local de la version courante (drift_schemas/)
	@echo "▶ Après un changement de schéma : bumper AppDatabase.schemaVersion,"
	@echo "  écrire le palier dans onUpgrade, puis relancer cette cible."
	dart run drift_dev make-migrations
	dart run drift_dev schema generate drift_schemas/app_database/ test/data/local/schema/

web-assets: ## Re-télécharge les actifs web (drift/sqlite3 depuis pubspec.lock, hls.js épinglé)
	./tool/web_assets.sh

hls-probe: ## Pilote HlsContentPlayer contre un vrai flux HLS dans un Chrome sans tête
	@echo "▶ Ni un test ni la CI : exige Chrome et le réseau."
	./tool/hls_probe.sh

clean: ## flutter clean
	flutter clean
