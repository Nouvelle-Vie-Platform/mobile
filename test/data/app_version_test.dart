import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/app_version.dart';

/// La lecture de la version du binaire.
///
/// Un seul point y compte vraiment, et il ne se voit qu'ici : l'implémentation
/// réelle **ne lève jamais**. Sous `flutter test` le canal de plugin n'existe
/// pas ; si l'exception remontait, tout test montant « À propos » rougirait
/// sans avoir rien demandé de tel — c'est le piège qu'`InertContentPlayer`
/// évite du côté du lecteur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sans canal de plugin, la lecture réelle rend null au lieu de lever',
      () async {
    const reader = PackageInfoAppVersionReader();

    await expectLater(reader.read(), completion(isNull));
  });

  test('le lecteur fixé rend ce qu\'on lui a donné', () async {
    const info = AppVersionInfo(version: '1.0.0', build: '1');

    expect(await const FixedAppVersionReader(info).read(), info);
    expect(await const FixedAppVersionReader(null).read(), isNull);
  });

  test('deux versions identiques sont égales', () {
    expect(
      const AppVersionInfo(version: '1.0.0', build: '1'),
      const AppVersionInfo(version: '1.0.0', build: '1'),
    );
    expect(
      const AppVersionInfo(version: '1.0.0', build: '1'),
      isNot(const AppVersionInfo(version: '1.0.0', build: '2')),
    );
  });
}
