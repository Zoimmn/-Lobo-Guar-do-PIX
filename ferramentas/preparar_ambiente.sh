#!/usr/bin/env bash
# Prepara um Linux (Ubuntu/Debian) para testar o jogo e gerar o APK pela
# linha de comando, sem abrir o editor. Instala o Godot 4.7.2, os modelos de
# exportação para Android e as ferramentas de assinatura.
#
# Uso: bash ferramentas/preparar_ambiente.sh
#
# Rode com o seu usuário normal: o script pede "sudo" só nos passos que mexem
# no sistema. O Godot e os modelos ficam na sua pasta pessoal
# (~/.local/share/godot), que é a mesma que o pipeline do GitHub guarda em cache.
set -euo pipefail

VERSAO="4.7.2"
BASE="https://github.com/godotengine/godot/releases/download/${VERSAO}-stable"
PASTA_GODOT="${HOME}/.local/share/godot"
EDITOR="${PASTA_GODOT}/editor/Godot_v${VERSAO}-stable_linux.x86_64"
MODELOS="${PASTA_GODOT}/export_templates/${VERSAO}.stable"

# Comandos de administrador: com "sudo" se não estivermos rodando como root.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

# 1. Editor do Godot (binário único). Se já estiver na pasta (por exemplo,
#    restaurado do cache), só cria o atalho "godot".
if [ ! -x "${EDITOR}" ]; then
	mkdir -p "$(dirname "${EDITOR}")"
	curl -fsSL --retry 3 -o /tmp/godot.zip "${BASE}/Godot_v${VERSAO}-stable_linux.x86_64.zip"
	unzip -q -o /tmp/godot.zip -d "$(dirname "${EDITOR}")"
	rm -f /tmp/godot.zip
fi
${SUDO} ln -sf "${EDITOR}" /usr/local/bin/godot

# 2. Modelos de exportação: só os arquivos do Android
if [ ! -f "${MODELOS}/android_release.apk" ]; then
	mkdir -p "${MODELOS}"
	curl -fsSL --retry 3 -o /tmp/modelos.tpz "${BASE}/Godot_v${VERSAO}-stable_export_templates.tpz"
	unzip -q -o -j /tmp/modelos.tpz 'templates/android_debug.apk' 'templates/android_release.apk' \
		'templates/android_source.zip' 'templates/version.txt' -d "${MODELOS}"
	rm -f /tmp/modelos.tpz
fi

# 3. Assinatura do APK, tela virtual e Java
${SUDO} env DEBIAN_FRONTEND=noninteractive apt-get update -qq
${SUDO} env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
	apksigner zipalign aapt xvfb default-jre-headless >/dev/null

# 4. Pasta no formato de SDK que o Godot espera, para máquinas sem o Android
#    SDK. O "adb" é só um marcador: ele serve para instalar direto no celular
#    por cabo, o que não é usado aqui. Se a variável ANDROID_HOME já apontar
#    para um SDK de verdade (como nos servidores do GitHub), ele é usado no lugar.
SDK="/opt/android-sdk"
${SUDO} mkdir -p "${SDK}/platform-tools" "${SDK}/build-tools/34.0.0"
printf '#!/bin/sh\nexit 0\n' | ${SUDO} tee "${SDK}/platform-tools/adb" >/dev/null
${SUDO} chmod +x "${SDK}/platform-tools/adb"
${SUDO} ln -sf /usr/bin/apksigner "${SDK}/build-tools/34.0.0/apksigner"
${SUDO} ln -sf /usr/bin/zipalign "${SDK}/build-tools/34.0.0/zipalign"

godot --headless --version
echo "Ambiente pronto. Gere o APK com: bash ferramentas/construir_apk.sh"
