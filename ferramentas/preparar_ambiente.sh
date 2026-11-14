#!/usr/bin/env bash
# Prepara um Linux (Ubuntu/Debian) para testar o jogo e gerar o APK pela
# linha de comando, sem abrir o editor. Instala o Godot 4.7.2, os modelos de
# exportação para Android e as ferramentas de assinatura.
#
# Uso: sudo bash ferramentas/preparar_ambiente.sh
set -euo pipefail

VERSAO="4.7.2"
BASE="https://github.com/godotengine/godot/releases/download/${VERSAO}-stable"
DESTINO="/opt/godot"
MODELOS="${HOME}/.local/share/godot/export_templates/${VERSAO}.stable"

# 1. Editor do Godot (binário único)
if ! command -v godot >/dev/null 2>&1; then
	mkdir -p "${DESTINO}/editor"
	curl -fsSL --retry 3 -o /tmp/godot.zip "${BASE}/Godot_v${VERSAO}-stable_linux.x86_64.zip"
	unzip -q -o /tmp/godot.zip -d "${DESTINO}/editor"
	ln -sf "${DESTINO}/editor/Godot_v${VERSAO}-stable_linux.x86_64" /usr/local/bin/godot
	rm -f /tmp/godot.zip
fi

# 2. Modelos de exportação: só os arquivos do Android
if [ ! -f "${MODELOS}/android_release.apk" ]; then
	mkdir -p "${MODELOS}"
	curl -fsSL --retry 3 -o /tmp/modelos.tpz "${BASE}/Godot_v${VERSAO}-stable_export_templates.tpz"
	unzip -q -o -j /tmp/modelos.tpz 'templates/android_debug.apk' 'templates/android_release.apk' \
		'templates/android_source.zip' 'templates/version.txt' -d "${MODELOS}"
	rm -f /tmp/modelos.tpz
fi

# 3. Assinatura do APK, tela virtual e Java
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
	apksigner zipalign aapt xvfb default-jre-headless >/dev/null

# 4. Pasta no formato de SDK que o Godot espera. O "adb" é só um marcador:
#    ele serve para instalar direto no celular por cabo, o que não é usado aqui.
SDK="/opt/android-sdk"
mkdir -p "${SDK}/platform-tools" "${SDK}/build-tools/34.0.0"
printf '#!/bin/sh\nexit 0\n' > "${SDK}/platform-tools/adb"
chmod +x "${SDK}/platform-tools/adb"
ln -sf /usr/bin/apksigner "${SDK}/build-tools/34.0.0/apksigner"
ln -sf /usr/bin/zipalign "${SDK}/build-tools/34.0.0/zipalign"

godot --headless --version
echo "Ambiente pronto. Gere o APK com: bash ferramentas/construir_apk.sh"
