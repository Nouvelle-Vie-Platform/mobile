# Makefile — Maison du Miracle
# Raccourcis pour démarrer un émulateur et lancer l'app.
# Surcharge possible : make android ANDROID_EMULATOR=Pixel_7_API_34

IOS_EMULATOR     ?= apple_ios_simulator
ANDROID_EMULATOR ?= emulateur_flutter

.DEFAULT_GOAL := help
.PHONY: help ios android web devices test analyze format l10n clean

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
	@echo "  make clean     flutter clean"

ios: ## Simulateur iOS + app
	@echo "▶ Démarrage du simulateur iOS ($(IOS_EMULATOR))…"
	-@flutter emulators --launch $(IOS_EMULATOR)
	@echo "⏳ Attente du simulateur…"
	@until xcrun simctl list devices booted | grep -q "Booted"; do sleep 2; done
	@echo "🚀 Lancement de l'app sur iOS…"
	@flutter run -d $$(xcrun simctl list devices booted | grep -oE "[0-9A-Fa-f-]{36}" | head -1)

android: ## Émulateur Android + app (nécessite un JDK 17/21)
	@echo "▶ Démarrage de l'émulateur Android ($(ANDROID_EMULATOR))…"
	-@flutter emulators --launch $(ANDROID_EMULATOR)
	@echo "⏳ Attente de l'émulateur…"
	@until adb devices | grep -qw device; do sleep 2; done
	@echo "🚀 Lancement de l'app sur Android…"
	@flutter run -d $$(adb devices | awk '$$2=="device"{print $$1; exit}')

web: ## Lance l'app dans Chrome
	flutter run -d chrome

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

clean: ## flutter clean
	flutter clean
