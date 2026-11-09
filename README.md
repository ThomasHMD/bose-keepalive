# bose-keepalive

Un petit outil pour Mac qui empêche une enceinte de se mettre en veille, en lui envoyant en continu un signal que vous n'entendez pas.

## Le problème

Beaucoup d'enceintes et de systèmes audio (c'est le cas de mon système Bose) s'éteignent ou passent en veille quand ils ne reçoivent plus de signal pendant un certain temps. C'est pratique pour l'énergie, mais agaçant au quotidien : après un moment de silence, il faut aller rallumer l'enceinte à la main, et on rate le début de la musique ou de la vidéo suivante.

## Le principe

L'idée est simple : si l'enceinte croit qu'elle reçoit un signal, elle ne s'endort pas. Le Mac lui envoie donc **une sinusoïde subsonique** : un son pur, très grave, à 20 Hz par défaut.

- **Pourquoi on ne l'entend pas.** 20 Hz est le bas de ce que l'oreille humaine peut percevoir, et à faible niveau il faudrait un volume énorme pour le sentir. Les enceintes elles-mêmes, même avec un caisson de basses, le restituent très peu. Dans la pratique, il n'y a rien à entendre.
- **Pourquoi l'enceinte le voit quand même.** Le détecteur de signal d'une enceinte mesure en général une tension à l'entrée, sans se soucier de la fréquence. Un signal à 20 Hz arrive jusqu'à lui comme n'importe quel autre.
- **Pourquoi c'est sans danger.** Le niveau est faible (quelques dizaines de décibels sous le maximum numérique), et à 20 Hz les haut-parleurs bougent à peine.
- **Pourquoi pas un ultrason.** On pourrait aussi utiliser un son trop aigu pour être entendu (au-dessus de 20 kHz), mais c'est une mauvaise idée : il peut chauffer les tweeters (les petits haut-parleurs d'aigus), gêner les animaux domestiques, et beaucoup de cartes son ne le reproduisent même pas. Un son très grave est plus sûr.

Le programme `bose-tone` calcule la sinusoïde en temps réel et ne s'interrompt jamais, avec un fondu d'une seconde à l'allumage et d'une demi-seconde à l'arrêt : pas de claquement quand vous le coupez ou le relancez. Si la configuration audio du Mac change (carte débranchée, par exemple), il relance le son tout seul.

## Prérequis

- **macOS.** L'outil utilise les composants audio du système et le gestionnaire de tâches de fond `launchd`.
- **`swiftc`**, le compilateur Swift, fourni par les outils en ligne de commande Xcode. Pour savoir si vous l'avez : `swiftc --version`. Sinon, `xcode-select --install` les installe (il n'y a pas besoin du Xcode complet).
- **SwiftBar** (facultatif), pour piloter l'outil depuis la barre des menus : [swiftbar.app](https://swiftbar.app).

## Installation

```bash
git clone https://github.com/ThomasHMD/bose-keepalive.git
cd bose-keepalive
./bose-keepalive.sh install
```

L'installation compile le générateur, enregistre un agent `launchd` et le lance. Le signal est ensuite relancé à chaque ouverture de session, et relancé tout seul s'il s'arrête. Les fichiers d'exécution (binaire, réglages, journal d'erreurs) sont rangés dans `~/Library/Application Support/bose-keepalive/`.

Le dossier cloné doit rester en place : le menu SwiftBar et le script de pilotage s'y réfèrent. Mettre l'outil à jour, c'est faire `git pull` puis relancer `./bose-keepalive.sh install`.

Par défaut, le signal est joué sur **la sortie son par défaut de votre Mac**, donc celle qui est choisie dans Réglages Système > Son. Si votre enceinte est branchée sur une carte son (une Scarlett 2i2, par exemple) qui n'est pas la sortie par défaut, donnez son nom (voir plus bas).

## Commandes

```bash
./bose-keepalive.sh status          # marche | coupe | panne | absent, puis fréquence et niveau
./bose-keepalive.sh off             # couper (la coupure tient après un redémarrage)
./bose-keepalive.sh on              # relancer (réinstalle si besoin)
./bose-keepalive.sh niveau -24      # changer le niveau, en dBFS
./bose-keepalive.sh test 10         # jouer le signal 10 secondes (coupez l'agent avant : off)
./bose-keepalive.sh uninstall       # tout arrêter et retirer
```

### Réglages

Trois réglages, qui se donnent en variables d'environnement au moment de l'installation et sont ensuite mémorisés :

| Variable | Défaut | Rôle |
|---|---|---|
| `FREQ` | `20` | Fréquence du signal, en hertz |
| `LEVEL_DB` | `-30` | Niveau, en dBFS (0 est le maximum, les valeurs négatives sont plus faibles) |
| `SORTIE` | vide | Nom de la carte son sur laquelle jouer ; vide = sortie par défaut du système |

Exemples :

```bash
FREQ=30 ./bose-keepalive.sh install
LEVEL_DB=-24 ./bose-keepalive.sh install
SORTIE="Scarlett 2i2 USB" ./bose-keepalive.sh install
```

Le nom de la carte est celui qu'affiche Réglages Système > Son > Sortie (ou la commande `system_profiler SPAudioDataType`). Quand un nom est donné, le signal est joué directement sur cette carte, et nulle part ailleurs : si elle est absente, rien n'est joué sur une autre sortie, et l'outil réessaie toutes les 30 secondes. Jouer directement sur la carte évite aussi les claquements que peut provoquer un logiciel de routage audio (Background Music, Loopback et ses semblables) placé comme sortie par défaut, qui rattrape de temps en temps l'écart d'horloge avec la vraie carte.

Pour revenir à la sortie par défaut après avoir nommé une carte : `./bose-keepalive.sh uninstall`, puis `./bose-keepalive.sh install`.

## Le menu SwiftBar

Si vous utilisez SwiftBar, reliez le plugin à son dossier de plugins (celui que vous avez choisi au premier lancement de SwiftBar) :

```bash
ln -s "$PWD/bose-keepalive.5m.sh" "<dossier de plugins SwiftBar>/"
```

Une icône apparaît dans la barre des menus : enceinte pleine quand le signal est envoyé, enceinte barrée quand il est coupé, triangle quand l'agent est installé mais arrêté. Le menu permet de :

- couper ou relancer le signal ;
- choisir le niveau : -36, -30, -24 ou -18 dBFS (si le signal est coupé, le niveau est enregistré sans rien relancer) ;
- ouvrir cette documentation.

Le menu ne s'affiche que si SwiftBar tourne : pensez à l'ajouter aux éléments d'ouverture de session de votre Mac.

## Limites

- Ce n'est pas garanti pour toutes les enceintes : certaines ignorent les signaux très faibles ou très graves. Voir la section suivante.
- Avec une carte son externe, son bouton de volume (s'il y en a un) atténue aussi ce signal. Presque à zéro, le signal peut passer sous le seuil de l'enceinte. De même, le volume du Mac joue sur le niveau envoyé.
- Quand `SORTIE` est vide, le signal suit la sortie par défaut du système. Si celle-ci change (casque branché, AirPlay), le signal part ailleurs que sur votre enceinte. Dans ce cas, donnez le nom de la carte.
- Le signal n'existe que tant que le Mac est allumé et éveillé : un Mac en veille n'envoie rien.
- Fonctionne uniquement sous macOS.

## Si ça ne marche pas

Si l'enceinte se met quand même en veille, dans l'ordre :

1. Vérifiez que l'agent tourne : `./bose-keepalive.sh status` doit répondre `marche`. Sinon, `./bose-keepalive.sh on`. Le journal `~/Library/Application Support/bose-keepalive/erreurs.log` contient une ligne par relance du son : s'il en contient beaucoup, quelque chose cloche côté audio.
2. **Montez le niveau**, par paliers : `./bose-keepalive.sh niveau -24`, puis `-18`. À 20 Hz, cela reste en principe inaudible.
3. **Montez la fréquence**, si l'enceinte filtre les très basses fréquences : `FREQ=30 ./bose-keepalive.sh install`, puis 40. Au-delà d'environ 40 Hz, un caisson peut commencer à le rendre audible : écoutez de près après chaque changement.
4. Vérifiez que le signal sort bien sur la bonne sortie : lancez un test (`off`, puis `test 10`) et, si besoin, donnez le nom de la carte avec `SORTIE`.

## Licence

MIT, voir [LICENSE](LICENSE).

Ce projet n'est affilié ni à Bose Corporation ni à aucun fabricant d'enceintes ; « Bose » désigne ici seulement le matériel pour lequel je l'ai écrit.
