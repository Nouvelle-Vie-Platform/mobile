/// Table de la collection répliquée `auth_channels` — **par quelles portes
/// l'application propose d'entrer**, et ce qu'elle annonce (#83, jumelle serveur
/// #468).
///
/// Les règles de `mediatheque_tables.dart` valent ici mot pour mot : aucune clé
/// étrangère entre collections, **on stocke ce que le serveur envoie**, chaque
/// ligne porte son jeton d'écriture ([SyncedRow]).
///
/// ## Une table pour **une ligne**
///
/// Côté serveur, `auth_settings` est un singleton (`id = 1`, garanti par la clé
/// primaire **et** un CHECK). La table n'en portera donc jamais qu'une — même
/// patron que `decor`, et le même argument : passer par le flux delta donne
/// gratuitement ce qu'il aurait fallu écrire à la main derrière une route
/// dédiée, à savoir *quand* la politique a changé. Un `GET /auth/channels`
/// obligerait à choisir entre redemander à chaque ouverture et garder
/// indéfiniment une politique que le portail a changée — c'est-à-dire, ici,
/// proposer une porte qu'on vient de fermer.
///
/// ## Aucune ligne n'est un état, et ce n'est pas celui-ci
///
/// Une table **vide** veut dire « je n'ai pas encore reçu les réglages », jamais
/// « aucun canal » : c'est l'état d'une application qui n'a pas encore
/// synchronisé, et le repli est alors l'**e-mail seul**
/// (`AuthChannelOffer.emailOnly`). La distinction se lit dans le DAO, qui est le
/// seul endroit à en décider.
///
/// ## Pas de tombstone, et aucun besoin
///
/// Le singleton ne se supprime pas : **fermer** un canal met un booléen à
/// `false`, et c'est cette ligne-là qui voyage. La fermeture se propage donc par
/// le flux normal, sans mécanisme de plus.
library;

import 'package:drift/drift.dart';

import '../converters/i18n_map_converter.dart';
import 'mediatheque_tables.dart' show SyncedRow;

/// Collection `auth_channels` (partition `reference`, aucun filtre de
/// périmètre : une porte d'entrée n'appartient à aucune branche).
///
/// Elle est servie **sans compte** côté serveur (`servesAnonymous: true`), et
/// c'est indispensable : l'écran de connexion est par définition regardé par
/// quelqu'un qui n'a pas de compte.
@DataClassName('AuthChannelsRow')
class AuthChannels extends Table with SyncedRow {
  @override
  String get tableName => 'auth_channels';

  /// `integer` côté serveur et non `SERIAL` — il n'y aura jamais qu'une ligne.
  /// Vaut toujours `1`, mais la colonne existe parce que le curseur composé du
  /// protocole en a besoin, et parce qu'une table locale n'a pas à supposer ce
  /// que le serveur garantit.
  IntColumn get id => integer()();

  /// Le canal **e-mail** est-il ouvert ? Livré à `true` : `MailOtpSender` part
  /// en SMTP, et c'est le seul canal qui envoie réellement un code.
  BoolColumn get emailOpen => boolean().withDefault(const Constant(true))();

  /// Le canal **téléphone** est-il ouvert ? Livré à `false`, et ce n'est pas un
  /// défaut prudent : c'est l'état réel du serveur, dont le pilote d'envoi
  /// (`OTP_PHONE_DRIVER`) n'envoie rien.
  BoolColumn get phoneOpen => boolean().withDefault(const Constant(false))();

  /// L'annonce du portail, **carte de traduction entière** (ADR-0023). `null` =
  /// le libellé du dépôt, jamais un message vide : c'est ce qui dit « il n'y a
  /// pas d'annonce » plutôt que « je n'ai pas encore reçu les réglages ».
  TextColumn get loginNotice =>
      text().map(const I18nMapConverter()).nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
