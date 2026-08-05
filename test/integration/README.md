# Tests d'intégration — contre un **vrai** serveur

Ces tests parlent en HTTP à une instance `new-life-server` en marche. Ils
n'utilisent **aucun** double d'`HttpClientAdapter` : ce qui est vérifié ici,
c'est précisément ce qu'une fixture ne peut pas prouver — que le serveur se
comporte comme l'ADR le décrit, et que le moteur client s'accorde avec lui.

Ils portent l'étiquette `live-server` et sont **sautés par défaut**
(`dart_test.yaml`), donc en CI, qui n'a pas de serveur.

## Monter le décor

### 1 · Le serveur

Depuis le dépôt `new-life-server` :

```sh
node ace migration:run
node ace db:seed
OTP_PHONE_DRIVER=log OTP_DEV_ECHO_CODE=true npm run dev
```

- `db:seed` crée le compte **super admin** (`SUPER_ADMIN_EMAIL` /
  `SUPER_ADMIN_PHONE` du `.env`), les intervenants et les rubriques. Sans lui,
  `POST /teachings` n'a rien à quoi s'accrocher.
- `OTP_PHONE_DRIVER=log` : le canal téléphone ne part pas, le code est
  **journalisé** (ligne `[OTP] fake sender`, champ `code`). C'est la valeur par
  défaut.
- `OTP_DEV_ECHO_CODE=true` : le même code est en plus rendu dans la réponse
  `202` de `POST /auth/request-code`, sous `debugCode`. C'est ce que les tests
  lisent — surveiller un fichier de log depuis Dart serait fragile, et la valeur
  est la même. **Dev/QA seulement** : l'application refuse de démarrer avec en
  production.

### 2 · Deux branches

Le scénario déplace une Home Branch d'une branche à une autre ; le seeder n'en
crée qu'**une** (l'église mère). En ajouter au moins une :

```sh
docker exec <conteneur-postgres> psql -U root -d new_life -c "
insert into branches (name, is_mother_church, address, postal_box, email, phone, created_at, updated_at)
select v.name, false, v.addr, v.pb, v.mail, v.tel,
       date_trunc('milliseconds', now()), date_trunc('milliseconds', now())
from (values
  ('Nouvelle Vie Kara','Kara','BP 1','kara@nouvellevietogo.org','+228 26 00 00 00'),
  ('Nouvelle Vie Atakpamé','Atakpamé','BP 2','atakpame@nouvellevietogo.org','+228 24 00 00 00')
) as v(name,addr,pb,mail,tel)
where not exists (select 1 from branches b where b.name = v.name);"
```

> Il n'existe **aucune** route qui crée une branche depuis l'API mobile, et
> celle du portail admin passe par une session web + CSRF. C'est la seule étape
> du décor qui touche la base — le scénario lui-même, lui, n'y touche jamais.
>
> ⚠️ **`date_trunc('milliseconds', …)` n'est pas de la coquetterie.** Le curseur
> composé du protocole encode `updated_at` en **millisecondes**
> (`cursorFromRow` → `toMillis()`), alors que PostgreSQL stocke des
> **microsecondes**. Une ligne dont l'`updated_at` porte des microsecondes
> non nulles satisfait sa propre borne keyset (`.089887 > .089`) : le tirage la
> resert indéfiniment, page après page. Un `now()` brut en SQL produit
> exactement ça. Les écritures de l'application, elles, passent par Lucid /
> luxon, qui n'écrivent qu'à la milliseconde — le cas ne se produit pas
> aujourd'hui par les chemins de l'app. Observé, et remonté dans le rapport de
> l'issue #31 ; le moteur client, lui, refuse de boucler (`SyncStalled`).

## Jouer

```sh
flutter test --run-skipped test/integration/
```

Réglages par `--dart-define`, tous facultatifs :

| Clé                        | Défaut                  | Rôle                                  |
| -------------------------- | ----------------------- | ------------------------------------- |
| `LIVE_SERVER_URL`          | `http://localhost:3333` | URL du serveur.                       |
| `LIVE_OPERATOR_IDENTIFIER` | `+22890000000`          | Le super admin, qui publie le décor.  |
| `LIVE_MEMBER_IDENTIFIER`   | `+22899000031`          | Le fidèle dont le périmètre bouge.    |

**Attendre 60 s entre deux exécutions** : `request-code` est limité à 1 code par
minute et par (identifiant, IP), et à 5 par heure. Une relance immédiate échoue
en `429 E_OTP_RATE_LIMITED`.

## Ce que le scénario laisse derrière lui

Chaque exécution publie 5 enseignements préfixés `[#31]` et incrémente deux fois
la `scope_version` du fidèle. Rien de tout cela ne gêne une relance — les
assertions ne portent que sur les identifiants du run en cours. Pour nettoyer :

```sh
docker exec <conteneur-postgres> psql -U root -d new_life \
  -c "delete from teachings where title like '[#31]%';"
```
