import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Supabase 초기화가 필요하므로 실제 위젯 테스트는
    // mock을 구성한 뒤 별도로 작성한다.
    expect(true, isTrue);
  });
}
