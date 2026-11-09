#!/bin/zsh
# <bitbar.title>Bose éveillé</bitbar.title>
# <bitbar.version>1.0</bitbar.version>
# <bitbar.author>Thomas Hammoudi</bitbar.author>
# <bitbar.desc>Coupe ou relance le signal inaudible qui empêche le Bose de se mettre en veille, et règle son niveau.</bitbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
#
# Rafraîchi toutes les 5 min (le .5m du nom) et après chaque clic. Toute la logique est dans
# bose-keepalive.sh, ce plugin ne fait que l'afficher et l'appeler. Doc : README.md.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
SELF="${0:A}"; BASE="${SELF:h}"; CTL="$BASE/bose-keepalive.sh"
GRIS="color=#8E8E93"
# Toujours via /bin/zsh : ne dépend pas du bit d'exécution de bose-keepalive.sh.
read -r etat freq niveau <<< "$(/bin/zsh "$CTL" status 2>/dev/null)"

case "$etat" in
  marche) icone=hifispeaker.fill; ligne="Bose maintenu éveillé"; action="Couper le signal"; cmd=off ;;
  coupe)  icone=speaker.slash;    ligne="Signal coupé, le Bose peut se mettre en veille"; action="Relancer le signal"; cmd=on ;;
  panne)  icone=exclamationmark.triangle; ligne="Agent installé mais arrêté"; action="Relancer le signal"; cmd=on ;;
  *)      icone=speaker.slash;    ligne="Non installé"; action="Installer et lancer"; cmd=install ;;
esac

echo " | sfimage=$icone"
echo "---"
echo "$ligne | size=13"
[[ -n "$freq" ]] && echo "${freq} Hz à ${niveau} dBFS | size=12 $GRIS"
echo "$action | bash=/bin/zsh param1='$CTL' param2=$cmd terminal=false refresh=true"
echo "---"
echo "Niveau du signal"
for n in -36 -30 -24 -18; do
  case $n in -36) note=" (le plus discret)" ;; -18) note=" (le plus fort)" ;; *) note="" ;; esac
  coche=""; [[ "$n" == "$niveau" ]] && coche=" checked=true"
  echo "--${n/-/−} dBFS${note} | bash=/bin/zsh param1='$CTL' param2=niveau param3=$n terminal=false refresh=true$coche"
done
echo "Documentation | bash=/usr/bin/open param1='$BASE/README.md' terminal=false"
