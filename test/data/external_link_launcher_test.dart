import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/external_link_launcher.dart';

/// Le lanceur en service (`url_launcher`) : il n'ouvre qu'une adresse
/// `http`/`https` bien formée, et ne lève jamais — pas même quand le greffon
/// manque, ce qui est le cas sous `flutter test`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const launcher = UrlLauncherExternalLinkLauncher();

  test('un schéma inattendu ne lance rien', () async {
    expect(
        await launcher.open('intent://scan/#Intent;scheme=zxing;end'), isFalse);
    expect(await launcher.open('file:///data/data/app/secret.db'), isFalse);
    expect(await launcher.open('javascript:alert(1)'), isFalse);
    expect(await launcher.open('tel:+22890000000'), isFalse);
  });

  test('une adresse illisible ou sans hôte ne lance rien', () async {
    expect(await launcher.open(''), isFalse);
    expect(await launcher.open('https://'), isFalse);
    expect(await launcher.open('pas une adresse'), isFalse);
  });

  test('une adresse https, sans greffon, rend false sans lever', () async {
    expect(await launcher.open('https://example.org/dons'), isFalse);
  });
}
