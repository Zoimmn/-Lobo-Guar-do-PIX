#!/usr/bin/env bash
# Roda os testes e gera o APK do jogo pela linha de comando.
#
# Uso: bash ferramentas/construir_apk.sh [caminho/de/saida.apk]
#
# O APK é assinado com a chave de depuração do projeto
# (ferramentas/android/lobo-guara-debug.keystore). Ela existe para que todas
# as versões de teste tenham a mesma assinatura e possam ser instaladas uma
# por cima da outra. Não serve para publicar em loja.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
SAIDA="${1:-${RAIZ}/build/LoboGuaraDoPIX.apk}"
CHAVE="${RAIZ}/ferramentas/android/lobo-guara-debug.keystore"
SDK="${ANDROID_HOME:-/opt/android-sdk}"
JAVA="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${CHAVE}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="android"
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="${CHAVE}"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
unset JAVA_TOOL_OPTIONS || true

cd "${RAIZ}"
mkdir -p "$(dirname "${SAIDA}")"

echo "== Importando o projeto =="
# Com o plugin de SQLite, a primeira importação de um projeto recém-clonado
# pode encerrar com erro ao sair. A segunda passada confirma que está tudo certo.
"${GODOT}" --headless --path . --import >/dev/null 2>&1 || true
"${GODOT}" --headless --path . --import >/dev/null 2>&1

# Caminhos do Java e do SDK nas configurações do editor (por máquina).
CONFIG="$(ls "${HOME}"/.config/godot/editor_settings-4*.tres 2>/dev/null | tail -1 || true)"
if [ -n "${CONFIG}" ]; then
	sed -i "s#^export/android/android_sdk_path = .*#export/android/android_sdk_path = \"${SDK}\"#" "${CONFIG}"
	sed -i "s#^export/android/java_sdk_path = .*#export/android/java_sdk_path = \"${JAVA}\"#" "${CONFIG}"
fi

echo "== Testes =="
"${GODOT}" --headless --path . res://testes/testes.tscn

echo "== Exportando o APK =="
"${GODOT}" --headless --path . --export-release "Android" "${SAIDA}" 2>&1 \
	| grep -vE '^ADDING|^$' | grep -v 'ks-pass' || true

test -s "${SAIDA}" || { echo "ERRO: o APK não foi gerado."; exit 1; }
echo "== Conferindo a assinatura =="
apksigner verify --verbose "${SAIDA}" | grep -E '^Verifies|v2 scheme|v3 scheme'
ls -la "${SAIDA}"
