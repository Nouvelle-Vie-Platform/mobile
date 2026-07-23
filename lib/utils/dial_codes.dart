/// Indicatifs téléphoniques internationaux des pays fréquents de l'app.
///
/// Sert au sélecteur d'indicatif de l'écran de saisie d'identifiant : on déduit
/// un indicatif par défaut du `countryCode` du locale appareil (repli **+228**,
/// Togo) et l'on construit l'identifiant final au format **E.164**.
library;

/// Un pays et son indicatif téléphonique international.
class DialCountry {
  const DialCountry(this.countryCode, this.dialCode, this.name);

  /// Code pays ISO 3166-1 alpha-2 (ex. `"TG"`).
  final String countryCode;

  /// Indicatif international, « + » compris (ex. `"+228"`).
  final String dialCode;

  /// Nom du pays (français).
  final String name;

  /// Drapeau emoji dérivé du code pays (paire de symboles régionaux).
  String get flag {
    if (countryCode.length != 2) return '';
    const base = 0x1F1E6; // Indicateur régional « A ».
    final cc = countryCode.toUpperCase();
    return String.fromCharCodes([
      base + (cc.codeUnitAt(0) - 0x41),
      base + (cc.codeUnitAt(1) - 0x41),
    ]);
  }
}

/// Indicatif de repli quand le pays est inconnu (Togo, **+228**).
const DialCountry kDefaultDialCountry = DialCountry('TG', '+228', 'Togo');

/// Table des pays fréquents (Afrique de l'Ouest + diaspora francophone).
///
/// Note : Canada et États-Unis partagent l'indicatif `+1`.
const List<DialCountry> kDialCountries = [
  DialCountry('TG', '+228', 'Togo'),
  DialCountry('BJ', '+229', 'Bénin'),
  DialCountry('GH', '+233', 'Ghana'),
  DialCountry('CI', '+225', "Côte d'Ivoire"),
  DialCountry('NG', '+234', 'Nigeria'),
  DialCountry('SN', '+221', 'Sénégal'),
  DialCountry('ML', '+223', 'Mali'),
  DialCountry('BF', '+226', 'Burkina Faso'),
  DialCountry('NE', '+227', 'Niger'),
  DialCountry('CM', '+237', 'Cameroun'),
  DialCountry('GA', '+241', 'Gabon'),
  DialCountry('CG', '+242', 'Congo'),
  DialCountry('CD', '+243', 'RD Congo'),
  DialCountry('FR', '+33', 'France'),
  DialCountry('BE', '+32', 'Belgique'),
  DialCountry('CH', '+41', 'Suisse'),
  DialCountry('LU', '+352', 'Luxembourg'),
  DialCountry('GB', '+44', 'Royaume-Uni'),
  DialCountry('CA', '+1', 'Canada'),
  DialCountry('US', '+1', 'États-Unis'),
];

/// Renvoie l'indicatif correspondant au [countryCode] (ex. issu du locale
/// appareil), avec repli sur [kDefaultDialCountry] (+228) si nul ou inconnu.
DialCountry dialCountryForCode(String? countryCode) {
  if (countryCode == null || countryCode.isEmpty) return kDefaultDialCountry;
  final cc = countryCode.toUpperCase();
  for (final country in kDialCountries) {
    if (country.countryCode == cc) return country;
  }
  return kDefaultDialCountry;
}

/// Construit un identifiant téléphone au format **E.164** à partir d'un
/// [dialCode] (ex. `"+228"`) et du [rawNumber] saisi par l'utilisateur.
///
/// Ne garde que les chiffres du numéro puis retire les zéros initiaux (le
/// « 0 » de numérotation nationale) avant de préfixer l'indicatif.
String toE164(String dialCode, String rawNumber) {
  var digits = rawNumber.replaceAll(RegExp(r'[^0-9]'), '');
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  return '$dialCode$digits';
}
