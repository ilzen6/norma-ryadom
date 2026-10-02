import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/server_address.dart';

void main() {
  test('принимает https-адрес и убирает завершающую косую черту', () {
    expect(ServerAddress.parse('  https://norma.example.ru/  ', allowCleartext: false), (
      'https://norma.example.ru',
      null,
    ));
    expect(ServerAddress.parse('https://norma.example.ru/api/', allowCleartext: false), (
      'https://norma.example.ru/api',
      null,
    ));
  });

  test('без разрешения на открытый HTTP пускает его только к локальному адресу', () {
    expect(ServerAddress.parse('http://192.168.1.5:8080', allowCleartext: false), (
      null,
      ServerAddressProblem.insecure,
    ));
    expect(ServerAddress.parse('http://127.0.0.1:8080', allowCleartext: false), ('http://127.0.0.1:8080', null));
    expect(ServerAddress.parse('http://10.0.2.2:8080', allowCleartext: false), ('http://10.0.2.2:8080', null));
  });

  test('в демо-сборке пускает HTTP к компьютеру в локальной сети', () {
    expect(ServerAddress.parse('http://192.168.1.5:8080', allowCleartext: true), ('http://192.168.1.5:8080', null));
  });

  test('отклоняет адреса без схемы, с другой схемой, запросом или логином', () {
    for (final text in [
      '',
      'norma.example.ru',
      'ftp://norma.example.ru',
      'https://',
      'https://norma.example.ru/?a=1',
      'https://user:pass@norma.example.ru',
    ]) {
      expect(ServerAddress.parse(text, allowCleartext: true), (null, ServerAddressProblem.invalid), reason: text);
    }
  });
}
