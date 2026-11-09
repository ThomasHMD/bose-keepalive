#!/bin/zsh
# bose-keepalive : garde éveillée une enceinte Bose (ou toute enceinte qui se met en veille sans
# signal) en lui envoyant en continu une sinusoïde subsonique inaudible (générateur bose-tone.swift,
# compilé à l'installation). Doc complète : README.md.
#
#   ./bose-keepalive.sh install        compile le générateur, installe l'agent launchd et le lance
#   ./bose-keepalive.sh on | off       relance / coupe (la coupure tient après redémarrage)
#   ./bose-keepalive.sh niveau -24     change le niveau en dBFS (conserve l'état marche/arrêt)
#   ./bose-keepalive.sh status         état de l'agent
#   ./bose-keepalive.sh test [s]       joue le signal s secondes (10 par défaut), agent coupé d'abord
#   ./bose-keepalive.sh uninstall      arrête et retire tout
# FREQ=30 ./bose-keepalive.sh install  change la fréquence (20 Hz par défaut)
# SORTIE="Nom" ./bose-keepalive.sh install  joue sur cette carte son (sortie par défaut du système si vide)
set -eu

LABEL=com.thomashammoudi.bose-keepalive
RUN_DIR="$HOME/Library/Application Support/bose-keepalive"
BIN="$RUN_DIR/bose-tone"
SRC="${0:A:h}/bose-tone.swift"
REGLAGE="$RUN_DIR/reglage"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

# Réglage : défaut < dernier réglage enregistré < variables d'environnement.
ENV_FREQ=${FREQ:-}; ENV_LEVEL=${LEVEL_DB:-}; ENV_SORTIE=${SORTIE:-}
FREQ=20; LEVEL_DB=-30; SORTIE=""   # SORTIE vide = sortie par défaut du système
[[ -f "$REGLAGE" ]] && source "$REGLAGE"
FREQ=${ENV_FREQ:-$FREQ}; LEVEL_DB=${ENV_LEVEL:-$LEVEL_DB}; SORTIE=${ENV_SORTIE:-$SORTIE}

compiler() {
  mkdir -p "$RUN_DIR"
  [[ -x "$BIN" && "$BIN" -nt "$SRC" ]] && return 0
  swiftc -O -swift-version 5 "$SRC" -o "$BIN" 2>/dev/null \
    || { echo "Compilation de bose-tone impossible (swiftc absent ?)" >&2; exit 1; }
  rm -f "$RUN_DIR/tone.wav"   # ancien fichier d'une version précédente
}

coupe() { launchctl print-disabled "$DOMAIN" | grep -qE "\"$LABEL\" => (disabled|true)" }
charge() { launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1 }

demarrer() {
  launchctl enable "$DOMAIN/$LABEL"
  charge && launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  # bose-tone met 0,7 s à s'éteindre (fondu) : attendre qu'il soit déchargé.
  for i in {1..50}; do charge || break; sleep 0.1; done
  launchctl bootstrap "$DOMAIN" "$PLIST"
}

# Compile le générateur, écrit le réglage et le plist. $1 = relancer (défaut) ou garder (respecte une coupure).
installer() {
  compiler
  printf 'FREQ=%s\nLEVEL_DB=%s\nSORTIE=%q\n' "$FREQ" "$LEVEL_DB" "$SORTIE" > "$REGLAGE"
  # La carte n'est passée à bose-tone que si elle est nommée.
  local arg_sortie=""
  [[ -n "$SORTIE" ]] && arg_sortie="    <string>${SORTIE//&/&amp;}</string>"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
    <string>$FREQ</string>
    <string>$LEVEL_DB</string>
$arg_sortie
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>$RUN_DIR/erreurs.log</string>
</dict>
</plist>
EOF
  if [[ "${1:-relancer}" == garder ]] && coupe; then
    echo "Réglé sur ${FREQ} Hz à ${LEVEL_DB} dBFS (reste coupé)."
  else
    demarrer
    echo "En marche : ${FREQ} Hz à ${LEVEL_DB} dBFS sur ${SORTIE:-la sortie par défaut}, relancé à chaque ouverture de session."
  fi
}

case "${1:-}" in
  install) installer relancer ;;
  niveau)  LEVEL_DB=${2:?niveau en dBFS, ex. -24}; installer garder ;;
  on)
    if [[ -f "$PLIST" && -x "$BIN" ]] && grep -q bose-tone "$PLIST"; then demarrer; else installer relancer; fi
    echo "En marche."
    ;;
  off)
    launchctl disable "$DOMAIN/$LABEL"
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    echo "Coupé (le Bose peut de nouveau se mettre en veille)."
    ;;
  uninstall)
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    launchctl enable "$DOMAIN/$LABEL"
    rm -f "$PLIST" "$BIN" "$REGLAGE" "$RUN_DIR/tone.wav"
    echo "Retiré."
    ;;
  status)
    if [[ ! -f "$PLIST" ]]; then echo "absent"
    elif coupe; then echo "coupe ${FREQ} ${LEVEL_DB}"
    elif charge && launchctl print "$DOMAIN/$LABEL" | grep -q "state = running"; then echo "marche ${FREQ} ${LEVEL_DB}"
    else echo "panne ${FREQ} ${LEVEL_DB}"
    fi
    ;;
  test)
    compiler
    charge && ! coupe && { echo "Agent en marche : le couper d'abord (off)."; exit 1; }
    echo "Lecture ${FREQ} Hz à ${LEVEL_DB} dBFS pendant ${2:-10} s…"
    "$BIN" "$FREQ" "$LEVEL_DB" "$SORTIE" & pid=$!
    sleep "${2:-10}"; kill -TERM $pid; wait $pid
    ;;
  *)
    sed -n '6,13p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
