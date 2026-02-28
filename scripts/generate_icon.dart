// ignore_for_file: avoid_print

/// 로고 파일 역할:
/// - laon_icon.svg: 앱 내부 로고 (스플래시, 로그인, 홈 등 → LaonIcon 위젯)
/// - laon_icon.png: 런처/앱 아이콘 (실행 전 겉에서 보이는 아이콘만)
///
/// PNG 파일을 바꾼 뒤에는 반드시: dart run flutter_launcher_icons
/// (이 스크립트는 SVG→PNG 변환 방법만 안내합니다.)
void main() {
  print('laon_icon.png(런처용) 교체 후 런처 아이콘 재생성:');
  print('  dart run flutter_launcher_icons');
  print('');
  print('SVG → PNG 변환이 필요하면:');
  print('1. assets/images/laon_icon.svg 를 브라우저 또는 Preview에서 열기');
  print('2. PNG로 내보내기 → assets/images/laon_icon.png 로 저장');
  print('3. dart run flutter_launcher_icons 실행');
  print('');
  print('온라인 변환: https://cloudconvert.com/svg-to-png');
}
