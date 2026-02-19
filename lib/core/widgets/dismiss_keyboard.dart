import 'package:flutter/material.dart';

/// 바깥 영역 터치 시 포커스(키보드)를 해제하는 래퍼.
/// [child] 위를 터치하면 [FocusScope.of(context).unfocus]를 호출하며,
/// [HitTestBehavior.translucent]로 자식도 터치를 받을 수 있게 한다.
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
