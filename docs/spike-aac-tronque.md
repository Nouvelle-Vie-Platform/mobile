# Spike — lire un `.aac` ADTS tronqué (server-portal#183)

> **Verdict : ADTS ✅.** Le format des fichiers téléchargeables reste
> **AAC-ADTS**, aux trois débits 64 / 128 / 192 kbps. Le repli MP3 CBR **n'est pas
> nécessaire** : il a été mesuré lui aussi, il marche, mais il ne corrige aucun
> défaut qui existerait côté ADTS.

Mesuré le 15/10/2026, avec `just_audio` 0.10.6 (la copie du dépôt), sur
**AVPlayer** (simulateur iPhone 17, iOS 26) et sur **ExoPlayer** (émulateur
Android API 28, x86_64). Les deux séries finissent sur `All tests passed!` et
`rc=0`.

## L'hypothèse testée

L'ADTS est une concaténation de trames, sans atome `moov` ni index : **tout
préfixe du fichier devrait être de l'audio valide**. Si c'était faux, tout le
chantier du téléchargement hors ligne basculait sur MP3 CBR.

## Le matériel de mesure

Source : `third_party/just_audio/example/audio/nature.mp3` (3,66 s) bouclée à
**297,970 s** de PCM 44,1 kHz stéréo — soit, une fois encodée, 12 834 trames AAC,
**298,005 s** exactement (bourrage de l'encodeur compris). Puis, pour chaque débit :

```sh
ffmpeg -v error -y -i src.wav -vn -c:a aac -b:a ${b}k -f adts full-${b}k.aac
head -c $(( $(stat -f%z full-${b}k.aac) * 40 / 100 )) full-${b}k.aac > trunc-${b}k.aac
```

Un fichier **entier** (`full-128k.aac`) sert de témoin dans la même série : sans
lui, on ne sait pas si un comportement vient de la troncature ou du lecteur.

## Ce que la troncature fait au fichier, hors lecteur

- Le décodage intégral du tronqué sort **119,16 à 119,21 s** d'audio pour une
  coupure à 40 % de 298,005 s. `ffmpeg` signale **une seule** trame abîmée (la
  dernière, coupée en plein milieu), la saute, et **sort en `rc=0`**.
- Le PCM décodé du tronqué est **identique bit à bit** à celui du fichier entier
  sur toute sa longueur moins la dernière seconde (même `md5`, aux trois débits).
  L'hypothèse « tout préfixe est de l'audio valide » est donc vraie **au niveau du
  codec**, pas seulement en principe.

## Ce que les lecteurs en font

| | durée annoncée | avance en 6 s de lecture | seek à 60 s | fin | erreurs |
| --- | --- | --- | --- | --- | --- |
| AVPlayer 64k | 119 071 ms | 6 007 ms / 6 012 ms | 60 000 ms | `completed` | aucune |
| AVPlayer 128k | 119 188 ms | 6 002 ms / 6 007 ms | 60 000 ms | `completed` | aucune |
| AVPlayer 192k | 120 232 ms | 6 012 ms / 6 017 ms | 60 000 ms | `completed` | aucune |
| ExoPlayer 64k | 119 494 ms | 5 939 ms / 6 012 ms | 60 000 ms | `completed` | aucune |
| ExoPlayer 128k | 119 411 ms | 5 939 ms / 6 007 ms | 60 000 ms | `completed` | aucune |
| ExoPlayer 192k | 119 456 ms | 5 957 ms / 6 011 ms | 60 000 ms | `completed` | aucune |

Lu : la lecture avance à la vitesse du son (6 s d'horloge murale → 6 s de
position), le seek tombe **à la milliseconde** sur la valeur demandée, et la
lecture poursuivie jusqu'à la coupure s'arrête sur l'état **`completed`** — pas
sur une erreur, pas sur une roue qui tourne. Un seek **au-delà** des octets reçus
(250 s dans un fichier qui en contient 119) ramène à la fin et reste
`completed` ; sur le fichier témoin entier, le même seek à 250 s atterrit à
252 005 ms (AVPlayer) et 251 979 ms (ExoPlayer), état `ready`. C'est exactement le comportement voulu par
le PRD F11 : « la lecture s'arrête proprement à la limite des octets reçus ».

## Le seul écart à connaître : la durée est une estimation

Un fichier ADTS **n'écrit sa durée nulle part**. Le lecteur la déduit du débit
observé, et l'encodeur AAC de ffmpeg est **ABR, pas CBR** — les trames mesurées
vont de 13 à 637 octets à 128 kbps. D'où :

- `ffprobe` annonce **295,1 / 297,4 / 307,1 s** pour un fichier entier qui en
  dure **298,005** : jusqu'à **+3,0 %** d'erreur à 192 kbps.
- Les lecteurs font nettement mieux : l'écart max mesuré est **+1,02 s** (AVPlayer,
  192 kbps), les autres sont sous **0,1 s**.
- Le même fichier en **MP3 CBR** (`-write_xing 0`) annonce **298,004875 s**,
  exactement, et ses trames font 417 ou 418 octets — le MP3 CBR est le seul des
  deux à donner une correspondance octets ↔ temps exacte.

Conséquence pratique, et c'est tout ce qu'il faut en retenir : **l'application ne
doit pas afficher la durée que lui donne le lecteur**, mais celle que la
synchronisation lui a transmise (PRD F3, le champ `download` porte déjà la
durée). La règle de trois octets ↔ temps, elle, reste bonne : sur le fichier
entier l'erreur moyenne est de **9 à 16 ms** et le pire point à **71 ms** — un
seek estimé depuis un octet tombe à moins d'un dixième de seconde.

## Ce qui n'est pas mesuré ici

- **Le son lui-même.** Aucune de ces mesures n'écoute : elles lisent des états et
  des positions. « Pas de bruit blanc à la coupure » reste à vérifier à l'oreille
  sur un appareil réel — c'est le point 6.1.c de `verification-sur-appareil.md`.
- **Un vrai téléphone.** L'émulateur Android décode en **logiciel** ; un Samsung ou
  un Tecno décode en **matériel**, et c'est le décodeur matériel qui, le cas
  échéant, se comporterait autrement sur une trame coupée. La série est donc à
  refaire une fois sur appareil physique, cf. `verification-sur-appareil.md` §6.

## Le piège du harnais, pour la prochaine fois

`AudioPlayer.play()` de `just_audio` **ne rend la main qu'à la fin du flux**. Un
`await lecteur.play()` suivi d'une attente de 3 s ne mesure pas 3 s de lecture :
il attend la fin du fichier, puis les 3 s. La première série de mesures a ainsi
donné « position = 119 164 ms après 3 s de lecture », qui ressemblait à une
anomalie du lecteur et n'était qu'un `await` de trop.
