# Vérification sur appareil réel — lecteur audio et fichiers tronqués

> **Pourquoi ce document.** Trois choses ne se prouvent qu'avec un téléphone dans
> la main : la gestion d'énergie du constructeur, la notification de lecture hors
> Pixel, et un vrai réseau mobile qui tombe. Un simulateur n'a ni l'une ni les
> autres. Le livrable d'une passe est un **compte rendu**, pas du code : on coche,
> et on note ce qu'on a vu quand ça diffère.

Ce protocole couvre deux passes qui se font ensemble :

- la **vérification du lecteur** (mobile#44), à refaire après toute reprise du
  moteur audio, de la notification ou de la gestion du réseau ;
- la **série « fichier tronqué » sur Android** (server-portal#183), qui confirme sur
  du matériel réel le format des téléchargements hors ligne — déjà tranché sur
  simulateur et émulateur dans `spike-aac-tronque.md`, mais pas encore sur un
  décodeur audio matériel.

Aucune connaissance des issues n'est nécessaire : tout est écrit ici.

---

## 0. Ce qu'il faut réunir avant de commencer

- [ ] Un **iPhone** physique (pas un simulateur), iOS 16 ou plus récent.
- [ ] Un **Android physique qui n'est pas un Pixel** — Samsung, Tecno, Infinix :
      c'est le parc réel des fidèles, et c'est là que la notification se comporte
      autrement. Android 13 ou plus récent de préférence, pour la permission de
      notification.
- [ ] Un **deuxième Android** si possible, en Android 12, pour le point 2.5.
- [ ] Un accès **au portail serveur** avec le droit de dépublier un contenu
      (pour le point 5.3). Prévenir avant : on va dépublier un vrai contenu
      quelques minutes.
- [ ] Un **enseignement d'au moins une heure** publié et lisible.
- [ ] Un **enseignement sans média** (pas d'enregistrement rattaché).
- [ ] Un **rassemblement** publié et lisible.
- [ ] Un forfait data utilisable : le point 4.3 consomme ~60 Mo.
- [ ] Les **fichiers de test tronqués** pour la partie 6, fabriqués sur un poste
      avec `ffmpeg` (la recette est au point 6.0).

Noter en tête du compte rendu : **modèle, version d'OS et version de l'app** de
chaque appareil. Sans ça, un symptôme n'est pas reproductible.

---

## 1. Lecture de base

1.1 — [ ] Ouvrir la médiathèque, ouvrir un enseignement, appuyer sur lecture.
→ **Attendu** : le son démarre en moins de ~5 s, la position avance, la jauge
suit.

1.2 — [ ] Appuyer sur pause, puis à nouveau sur lecture.
→ **Attendu** : reprise **à la position**, pas au début.

1.3 — [ ] Quitter l'écran du lecteur (retour arrière) pendant que ça joue.
→ **Attendu** : le son **continue**. Le mini-lecteur reste visible.

1.4 — [ ] Rouvrir le même enseignement.
→ **Attendu** : on retombe sur la lecture **en cours**, elle ne **redémarre
pas** au début.

---

## 2. Arrière-plan et écran verrouillé

2.1 — [ ] Lancer la lecture, puis **verrouiller l'écran**.
→ **Attendu** : le son continue sans coupure ni baisse de volume.

2.2 — [ ] Regarder l'**écran verrouillé**.
→ **Attendu** : on y lit le **titre** du contenu, le **nom de l'intervenant**, et
on y voit le **visuel** du contenu — pas une icône générique d'application.

2.3 — [ ] Appuyer sur **pause** depuis l'écran verrouillé, puis sur **lecture**.
→ **Attendu** : le lecteur obéit réellement, et l'écran de l'app (une fois
déverrouillé) affiche le même état. Pas de désynchronisation « l'app croit que ça
joue ».

2.4 — [ ] Basculer l'app en arrière-plan (bouton d'accueil), attendre **5 minutes
pleines** écran éteint, puis reprendre la lecture depuis l'écran verrouillé.
→ **Attendu** : le son repart. **Sur Android 12 et plus** : aucune disparition de
la notification, aucun plantage. C'est le geste le plus banal d'un fidèle, et
c'est celui qui casse quand le service de premier plan est arrêté à la pause.

2.5 — [ ] *(Android 12 spécifiquement)* Même geste que 2.4, mais attendre **15
minutes**.
→ **Attendu** : la reprise fonctionne encore. Si l'app se ferme avec une erreur
mentionnant `ForegroundServiceStartNotAllowedException`, **noter la trace** : c'est
un échec, pas un hasard.

2.6 — [ ] *(Android 13 et plus, à la **première** installation)* Au premier
lancement d'une lecture, observer la demande de permission de notification.
→ **Attendu** : la permission est **demandée explicitement**. La **refuser** :
→ **Attendu** : la lecture fonctionne quand même, l'app ne plante pas ; seule la
notification manque.

2.7 — [ ] **La durée affichée sur l'écran verrouillé, sur une copie
téléchargée** (#229). Télécharger un enseignement d'au moins une heure, passer
en **mode avion** (pour être sûr de jouer le `.aac` et non le HLS), le lancer,
noter la durée totale que l'**application** affiche, puis verrouiller l'écran et
noter celle que le **système** affiche.
→ **Attendu** : **le même chiffre à la seconde**. C'est le seul endroit où le
correctif se voit : avant, le système montrait l'estimation du lecteur sur
l'ADTS — jusqu'à 1,02 s d'écart mesuré, et −0,9 % à +4,8 % pour une estimation
par le conteneur, soit ~6 minutes sur deux heures. **Noter les deux chiffres**,
pas « ça correspond » : un écart de quelques secondes est exactement le symptôme
qu'on cherche.

2.8 — [ ] **Le « +30 s » de l'écran verrouillé près de la fin**, même copie
téléchargée. Se placer à une minute de la fin, puis appuyer **plusieurs fois**
sur « +30 s » depuis l'écran verrouillé.
→ **Attendu** : la position s'arrête à la fin et la lecture se termine
proprement. `SeekHandler` borne ses avances sur la durée annoncée au système,
qui est désormais celle du contrat : si celle-ci dépasse de quelques secondes la
fin réelle des octets du `.aac`, le dernier appui demande une position qui
n'existe pas. **Attendu quand même** : pas de plantage, pas de roue qui tourne,
pas de retour au début. **Noter ce qui se passe** — c'est le seul geste de la
tranche qu'aucun test ne couvre.

2.9 — [ ] **En HLS, rien ne doit changer.** Hors mode avion, sur un
enseignement **non téléchargé**, refaire 2.2 et 2.7.
→ **Attendu** : la durée arrive sur l'écran verrouillé comme avant (quelques
secondes après le début, le temps du manifeste) et les ±30 s fonctionnent. Une
durée qui resterait **vide** sur l'écran verrouillé en HLS serait la régression
exacte de cette tranche : le flux du lecteur aurait été réduit au silence sur un
chemin où il doit parler.

---

## 3. La notification, sur un Android qui n'est pas un Pixel

À faire **sur le téléphone non-Pixel**, avec un enseignement normal (donc un seul
élément dans la file de lecture — c'est exactement notre cas, un contenu = une
source, et c'est la configuration dans laquelle des boutons invisibles ont été
rapportés en amont).

3.1 — [ ] Lancer une lecture, dérouler le volet de notifications.
→ **Attendu** : la notification montre le titre, le visuel, et des **boutons
lecture/pause visibles et lisibles**. Si les boutons sont **absents ou
invisibles**, prendre une **capture d'écran** : c'est le symptôme attendu de la
régression amont, et il remonte au choix du moteur de notification.

3.2 — [ ] Appuyer sur pause depuis la notification, puis sur lecture.
→ **Attendu** : le lecteur obéit, et l'icône de la notification change d'état.

3.3 — [ ] Arrêter complètement la lecture (ou terminer le contenu).
→ **Attendu** : la notification **disparaît**. Elle ne reste pas coincée dans le
volet, et on ne peut pas la « réveiller » en tapant dessus plus tard.

3.4 — [ ] Tuer l'application depuis le sélecteur de tâches pendant la lecture.
→ **Attendu** : le son s'arrête et la notification disparaît. Pas de notification
orpheline, pas de service qui survit.

---

## 4. Le réseau réel

4.1 — [ ] En 4G, lancer la lecture d'un enseignement, laisser jouer 30 s, puis
activer le **mode avion**.
→ **Attendu** : le son s'interrompt et l'écran affiche **« Lecture
interrompue »** — un message, pas un écran de panne, pas un silence qui dure.

4.2 — [ ] Couper le mode avion, attendre le réseau, appuyer sur **« Reprendre »**.
→ **Attendu** : la lecture repart **à la position où elle s'est arrêtée**, pas au
début. Noter la position avant et après : l'écart doit être de quelques secondes
au plus.

4.3 — [ ] *(iOS spécifiquement)* Refaire 4.1 sur l'iPhone, chronomètre en main.
→ **Attendu** : iOS ne remonte **aucune erreur** de lui-même dans ce cas — c'est
un chien de garde côté app qui doit basculer l'écran en « Lecture interrompue ».
**Noter le délai mesuré** entre la coupure réseau et l'apparition du message. Il
doit être assez long pour ne pas casser une mise en tampon normale en 64 kbps
(donc pas 2 s) et assez court pour ne pas laisser l'utilisateur devant un écran
muet (donc pas 60 s).

4.4 — [ ] **Flux d'une heure, en 4G, écouté d'un bout à l'autre.** Lancer, poser
le téléphone, revenir au bout d'une heure.
→ **Attendu** : aucune coupure silencieuse, la position affichée à la fin
correspond à la durée réelle écoulée (pas de dérive de plusieurs minutes), et
l'app ne s'est pas fait tuer par le système pour cause de mémoire. Noter la
consommation mémoire si l'appareil sait l'afficher.

4.5 — [ ] En pleine écoute en 4G, **se connecter à un wifi** (sans couper la
lecture).
→ **Attendu** : la lecture **ne casse pas**. Au pire un bref arrêt de mise en
tampon, jamais une erreur ni un retour au début.

4.6 — [ ] L'inverse : en wifi, **sortir de portée** ou couper le wifi pour
basculer en 4G.
→ **Attendu** : idem, la lecture survit.

---

## 5. Les états d'absence et la rétractation

5.1 — [ ] Ouvrir l'enseignement **sans média**.
→ **Attendu** : l'écran annonce **« Enregistrement à venir »**. Pas un écran de
panne, pas un bouton lecture mort, pas de roue qui tourne indéfiniment.

5.2 — [ ] Mode avion activé, ouvrir un enseignement **qui a un média**.
→ **Attendu** : l'écran dit que **la médiathèque s'écoute en ligne**. Surtout
**pas** « cet enregistrement n'a pas été téléchargé » (ça promettrait une fonction
de téléchargement) ni « contenu retiré » (ce serait un mensonge).

5.3 — [ ] **La rétractation en direct.** Lancer la lecture d'un enseignement sur
l'appareil, **verrouiller l'écran**, puis depuis le portail serveur **dépublier**
ce même enseignement. Attendre la synchronisation.
→ **Attendu** : le son **se coupe**, et l'**écran verrouillé se vide** (plus de
titre, plus de visuel, plus de commandes). C'est le scénario qu'aucun test
automatisé ne couvre de bout en bout. Republier ensuite le contenu.

---

## 6. Série « fichier tronqué » sur Android (server-portal#183)

Cette partie tranche le **format des téléchargements hors ligne**. L'hypothèse à
casser : un `.aac` en ADTS est une simple concaténation de trames, sans index ni
en-tête global, donc **n'importe quel préfixe du fichier devrait être de l'audio
valide et lisible**. Si ExoPlayer lit mal un `.aac` coupé en plein milieu, tout le
chantier bascule sur du **MP3 CBR** (le reste de la conception est identique).

La série a déjà été passée sur simulateur iOS et sur émulateur Android, et elle
passe : le verdict et les chiffres sont dans `spike-aac-tronque.md`. Ce qui reste
à faire ici, c'est la même série sur un **téléphone physique**, parce qu'un
émulateur décode en logiciel là où un vrai appareil décode en matériel — et c'est
le décodeur matériel qui, le cas échéant, trébucherait sur une trame coupée.

### 6.0 Fabriquer les fichiers (sur un poste avec `ffmpeg`)

À partir d'une source audio d'au moins cinq minutes (`src.wav`) :

```sh
for b in 64 128 192; do
  ffmpeg -v error -y -i src.wav -vn -c:a aac -b:a ${b}k -f adts full-${b}k.aac
  head -c $(( $(stat -f%z full-${b}k.aac) * 40 / 100 )) full-${b}k.aac > trunc-${b}k.aac
done
```

Noter la **durée réelle** de la source (ici ~298 s) : les fichiers tronqués à 40 %
doivent s'arrêter vers **119 s**. C'est le chiffre de référence de toute la série.

Pousser les six fichiers sur l'appareil :

```sh
adb push trunc-64k.aac trunc-128k.aac trunc-192k.aac /sdcard/Download/
```

### 6.1 Pour chacun des trois débits (64k, 128k, 192k)

6.1.a — [ ] Ouvrir le fichier tronqué dans le lecteur de test et lancer la
lecture depuis le début.
→ **Attendu** : le son démarre normalement et est **propre** — pas de bruit
blanc, pas de craquement, pas de son haché.

6.1.b — [ ] Noter la **durée annoncée** par le lecteur.
→ **Attendu** : une valeur **proche de 119 s**, pas zéro, pas « inconnu », pas la
durée du fichier complet. **Noter l'écart exact** : en ADTS la durée est *estimée*
à partir du débit, elle n'est jamais écrite dans le fichier. Un écart de quelques
secondes est le comportement attendu ; un écart de plusieurs dizaines de secondes
est un résultat à remonter.

6.1.c — [ ] Se positionner à **110 s** et laisser jouer jusqu'à la coupure.
→ **Attendu** : la lecture s'arrête **proprement** à la fin des octets reçus.
L'état du lecteur passe à « terminé ». **Pas** de plantage, **pas** de bruit
blanc sur la dernière seconde, **pas** de blocage avec une roue qui tourne
indéfiniment, **pas** de boucle de réessai.

6.1.d — [ ] Se positionner à **60 s**, vérifier la position affichée, puis
laisser jouer 10 s.
→ **Attendu** : on atterrit à 60 s à moins d'une seconde près, et le son reprend
immédiatement et proprement.

6.1.e — [ ] Se positionner **au-delà de la coupure** (par exemple 250 s, dans la
zone qui n'a pas été téléchargée).
→ **Attendu** : le lecteur s'arrête proprement ou revient à la fin des octets
reçus. **Pas** de plantage, **pas** de blocage définitif, **pas** d'erreur
remontée à l'utilisateur.

6.1.f — [ ] Mettre l'appareil en **mode avion** et refaire 6.1.a.
→ **Attendu** : rien ne change — c'est un fichier local, il ne doit jamais
dépendre du réseau.

### 6.2 Verdict

- [ ] **Les trois débits passent les six gestes** → ADTS validé, le format des
      téléchargements reste `.aac`.
- [ ] **Un seul débit échoue sur un seul geste** → noter lequel, avec le modèle et
      la version d'Android, et refaire **exactement la même série** avec des
      fichiers MP3 CBR :
      `ffmpeg -i src.wav -vn -c:a libmp3lame -b:a ${b}k -write_xing 0 -f mp3 full-${b}k.mp3`.
      Si le MP3 passe là où l'ADTS échoue, le chantier bascule sur MP3 CBR.

---

## 7. Les deux familles de contenus

7.1 — [ ] Ouvrir un **rassemblement** et l'écouter.
→ **Attendu** : le **même écran** qu'un enseignement, et les mêmes garanties —
lecture en arrière-plan, écran verrouillé renseigné, reprise à la position. Si
quelque chose diffère, c'est que les deux familles ne passent pas par le même
chemin, et c'est un défaut en soi.

---

## 8. Le magasin des médias de la messagerie survit-il ? (#223)

Ce que les tests ne peuvent pas prouver : un dossier **durable** l'est par
promesse du système, pas par mesure locale. Trois gestes, et aucun ne demande le
réseau une seconde fois.

8.1 — [ ] Ouvrir un **document** reçu dans une conversation, puis passer en
**mode avion** et le rouvrir.
→ **Attendu** : il s'ouvre, sans message d'indisponibilité. S'il échoue, le
magasin n'est pas celui qu'on croit (vérifier qu'il est bien sous
`getApplicationSupportDirectory`, et non dans le cache).

8.2 — [ ] Tuer l'application, la relancer, rouvrir le même document hors ligne.
→ **Attendu** : identique. Le chemin est noté en base (`local_message_media`),
il ne vit pas en mémoire.

8.3 — [ ] Laisser l'appareil **une nuit** (ou forcer la pression sur le
stockage : remplir la mémoire jusqu'à l'avertissement du système), puis rouvrir
le document hors ligne.
→ **Attendu** : il est toujours là. **Noter ce qui se passe s'il a disparu** —
c'est le seul moyen de savoir si l'OS touche à ce dossier, et le chantier n'a
aucune autre source que cette observation.

---

## 8 bis. La descente automatique en wifi (#225)

Ce que la VM Dart ne peut pas dire : elle sait prouver la **règle** — en données
mobiles, zéro téléchargement —, pas que l'OS annonce le bon tuyau au bon moment.
C'est toute la question, et elle n'a pas de double.

8bis.1 — [ ] Réglage **Qualité & données → MESSAGERIE** sur « En wifi ».
Couper le wifi (données mobiles seules), se faire envoyer **une photo et une
vidéo** dans un groupe, les laisser arriver, puis passer en **mode avion** et
remonter le fil.
→ **Attendu** : les bulles ne peignent pas les images (elles sont au serveur, pas
ici). L'onglet MESSAGERIE annonce alors **un poids en attente** — noter le
chiffre, il doit être celui des deux fichiers.

8bis.2 — [ ] **Rebrancher le wifi** sans rien toucher à l'application, attendre,
puis repasser en mode avion et remonter le fil.
→ **Attendu** : les deux médias s'affichent hors ligne, et le poids en attente
de l'onglet MESSAGERIE est retombé à « Tout est déjà sur l'appareil ». **Noter
combien de temps** s'est écoulé entre le retour du wifi et l'affichage : la file
part après un **cycle de synchronisation**, pas sur un signal de réseau à elle,
et c'est le seul endroit où ce délai se mesure. S'il dépasse la minute, dire
lequel des cinq déclencheurs a fini par l'ouvrir (le fil rouvert, le retour au
premier plan, un tirer-pour-rafraîchir).

8bis.3 — [ ] Réglage sur « Jamais », se faire envoyer une photo, rester en wifi.
→ **Attendu** : rien ne descend. Puis **ouvrir** la photo : elle est gardée, et
se revoit en mode avion. « Jamais » ne parle que du tout seul.

8bis.4 — [ ] Réglage sur « Toujours », wifi coupé, se faire envoyer une photo.
→ **Attendu** : elle descend sur les données mobiles. C'est le seul choix qui
consomme le forfait, et il faut le voir consommer.

8bis.5 — [ ] **Remplir le stockage** jusqu'à l'avertissement du système, puis se
faire envoyer une vidéo en wifi.
→ **Attendu** : rien ne plante, et le fil reste utilisable. ⚠️ Le pré-check
d'espace **avant** le premier octet est aujourd'hui inerte sur ce socle :
`BestEffortDiskSpace.freeBytes()` rend « inconnu » faute d'API Dart
multiplateforme, et l'inconnu laisse passer. Le seul filet réel est celui du
système au moment d'écrire. **Noter ce que l'appareil fait** — c'est la seule
source dont on dispose pour décider s'il faut un canal natif.

---

## 9. La place libre est-elle vraiment mesurée ? (#236)

`freeBytes()` rend désormais un nombre, par canal natif (`StatFs` sur Android,
`volumeAvailableCapacityForImportantUsage` sur iOS). Les tests Dart prouvent le
décodage et la règle « échec ⇒ `null`, jamais `0` ». **Ce qu'aucun test ne peut
prouver, c'est que le nombre soit le bon**, et c'est précisément ce qui décide
si le pré-check bloque à tort.

Il faut donc **remplir l'appareil**. Une grosse vidéo copiée, ou l'appareil
photo laissé tourner, jusqu'à descendre sous ~200 Mo libres.

9.1 — [ ] Appareil **presque plein**, lancer le téléchargement d'un
enseignement **plus gros que la place restante**.
→ **Attendu** : il échoue **immédiatement**, avec « espace insuffisant », sans
qu'un seul octet parte. **Noter le nombre d'octets libres annoncé par les
réglages du système** et la taille annoncée de l'enseignement : c'est le seul
moyen de voir si la mesure est juste ou décalée.

9.2 — [ ] Même appareil plein, lancer un enseignement **plus petit** que la
place restante.
→ **Attendu** : il part normalement. Si **celui-là** est refusé, la mesure est
trop basse et le pré-check bloque à tort — c'est le pire cas, pire que pas de
pré-check du tout. **Le signaler avec les deux chiffres.**

9.3 — [ ] **iOS seulement**, et c'est le point qui a décidé l'API retenue :
comparer le refus à ce que l'application *Réglages* annonce comme espace libre.
→ **Attendu** : le refus se prononce bien avant que *Réglages* affiche 0. iOS
compte du « purgeable » que l'application n'obtiendra pas ; si le
téléchargement part alors que le disque est plein et échoue en cours, c'est que
la mesure compte le purgeable — vérifier qu'on n'est pas revenu à
`systemFreeSize`.

9.4 — [ ] Android **avec une carte SD** si on en a un.
→ **Attendu** : le refus suit l'espace de la **mémoire interne**, pas celui de
la carte. L'application n'écrit que dans son bac à sable interne.

9.5 — [ ] Un appareil **non rempli**, téléchargement normal.
→ **Attendu** : rien ne change. Une régression ici voudrait dire que la mesure
rend `0` au lieu de `null` quelque part, et elle bloquerait **tout** le monde.
C'est la case à cocher en premier.

⚠️ **Non couvert ici** : les médias **reçus** de la messagerie. La descente
automatique (#225) n'existe pas encore, et rien n'appelle `freeBytes()` sur ce
chemin-là — le pré-check de la messagerie reste à écrire avec la file.

---

## 10. Le compte rendu

Reprendre la liste ci-dessus en gardant **toutes** les cases, cochées ou non, et
ajouter en tête :

- modèle, version d'OS et version de l'app, pour **chaque** appareil utilisé ;
- la date et le type de réseau (opérateur, 4G/5G) ;
- pour chaque case **non cochée** : ce qui s'est passé à la place, en une phrase
  observable (« le son s'est arrêté sans message pendant 40 s »), une capture
  d'écran si c'est visuel, et la trace si l'app a planté ;
- pour les points qui demandent un chiffre (2.7, 4.3, 4.4, 6.1.b, 6.1.d, 9.1,
  9.2) : **le chiffre**, pas « ça marche ».

Une case cochée sans chiffre là où un chiffre est demandé ne vaut rien.
