import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/datasources/local/device_id.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('最初は、サーバーが受け付ける形式(16〜64文字の英数字)で、作る', () async {
    final id = await DeviceId().get();

    expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{16,64}$')));
  });

  test('2回目以降は、同じ識別子を返す(ログアウトしても、変わらない)', () async {
    final first = await DeviceId().get();
    // アプリを再起動した想定で、別のインスタンスから読む。
    final second = await DeviceId().get();

    expect(second, first);
  });

  test('保存済みの識別子があれば、それを使う', () async {
    SharedPreferences.setMockInitialValues({'device.id': 'saved-0123456789abcdef'});

    expect(await DeviceId().get(), 'saved-0123456789abcdef');
  });

  test('端末が違えば、識別子も違う', () async {
    final first = await DeviceId().get();
    SharedPreferences.setMockInitialValues({});
    final other = await DeviceId().get();

    expect(other, isNot(first));
  });
}
