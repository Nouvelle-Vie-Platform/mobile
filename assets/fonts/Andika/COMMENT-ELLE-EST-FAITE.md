# Andika — la police des textes en éwé

**Pourquoi elle est là.** Aucune des trois polices de l'application ne porte les
lettres de l'éwé : `ɔ ɖ ɛ ƒ ɣ ŋ ʋ` et leurs capitales manquent à Atkinson
Hyperlegible, à Literata et à Playfair Display — mesuré le 30/10/2026. Sur un
téléphone, le système comble en silence. **Dans un navigateur, non** : CanvasKit
irait chercher une police de secours chez Google, que la CSP de
`app.eenv.brainsial.com` et la règle « aucun CDN au démarrage » interdisent
toutes deux. Le fidèle lisait donc des carrés vides au milieu de l'Écriture.

**Pourquoi Andika**, et pas une autre. Trois candidates couvraient l'éwé ;
l'écart métrique à Atkinson a tranché, parce que c'est la police qu'on garde
partout ailleurs :

| Police | Lettres éwé manquantes | Écart à Atkinson |
| --- | --- | --- |
| **Andika** | **aucune** | **8,9 %** |
| Source Sans 3 | `Ɖ Ʋ` | 3,8 % |
| Noto Sans | aucune | 17,7 % |
| Open Sans, Lexend, Nunito Sans | 9 lettres | — |

Source Sans est plus proche en métrique et perdait deux capitales que l'éwé
emploie (`Ɖeka`) : on serait retombé en carrés vides sur un mot sur cent, ce qui
est pire qu'un écart de dessin. Andika est par ailleurs, comme Atkinson, une
police **conçue pour la lisibilité** — SIL l'a dessinée pour l'alphabétisation
dans les langues africaines.

## Elle est détourée, et c'est mesuré

Andika complète pèse 912 Ko en deux graisses. Flutter web télécharge **toutes**
les polices déclarées au démarrage, même celles qu'aucun écran n'utilise : ces
912 Ko auraient été payés par chaque fidèle, y compris ceux qui ne lisent qu'en
français. Détourée, elle pèse **265 Ko** (51 Ko une fois en brotli).

Les plages gardées, et la commande qui les applique :

```bash
PLAGES="U+0020-007E,U+00A0-02AF,U+0300-036F,U+1E00-1EFF,U+2010-2027,U+2030-205E,U+20AC,U+2122"
pyftsubset Andika-Regular-complete.ttf --unicodes="$PLAGES" \
  --layout-features='*' --output-file=Andika-Regular.ttf
```

> ⚠️ **`U+0250-02AF` n'est pas décoratif.** Au premier essai la plage s'arrêtait à
> `U+024F` — la fin du latin étendu B — et les cinq lettres les plus fréquentes de
> l'éwé (`ɔ ɖ ɛ ɣ ʋ`) vivent **juste après**, dans le bloc phonétique. La police
> détourée s'installait sans rien dire et rendait exactement les mêmes carrés
> vides qu'avant. C'est ce qu'un détourage fait de pire : il échoue en silence.
>
> D'où `bible_ewe_font_test.dart`, qui relit la table de la police posée et exige
> qu'elle couvre **le texte réel** de la Bible éwé. Un détourage trop serré y
> rougit.

Source : [Google Fonts](https://fonts.google.com/specimen/Andika), SIL Open Font
License 1.1 (`OFL.txt`).
