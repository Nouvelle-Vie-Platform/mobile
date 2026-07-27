import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';

void main() {
  group('Mock d\'authentification — code à 6 chiffres', () {
    late InMemoryAuthRepository repository;

    setUp(() => repository = InMemoryAuthRepository());

    test('le code magique fait 6 chiffres, comme celui du serveur', () {
      expect(InMemoryAuthRepository.magicCode, hasLength(6));
      expect(
        RegExp(r'^\d{6}$').hasMatch(InMemoryAuthRepository.magicCode),
        isTrue,
      );
    });

    test('le code magique ouvre une session', () async {
      final session = await repository.verifyCode(
        identifier: 'jean@example.org',
        code: InMemoryAuthRepository.magicCode,
      );

      expect(session.user.email, 'jean@example.org');
      expect(session.token, isNotEmpty);
    });

    test('l\'ancien code à 4 chiffres est refusé', () async {
      // Le mock doit se tromper comme la production : `0000` ne passe plus.
      await expectLater(
        repository.verifyCode(identifier: 'jean@example.org', code: '0000'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.invalidCode),
        ),
      );
    });

    test('un autre code à 6 chiffres est refusé', () async {
      await expectLater(
        repository.verifyCode(identifier: 'jean@example.org', code: '123456'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
