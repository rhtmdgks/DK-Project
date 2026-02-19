import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/responsive.dart';

/// 비동기 데이터 로딩의 세 가지 상태(로딩 / 에러 / 빈 목록)를 처리하는 공용 위젯.
///
/// 반복되는 `if (_loading) ... if (_error) ... if (_items.isEmpty)` 패턴을 제거한다.
/// 반응형: 텍스트와 간격이 화면 크기에 비례하여 스케일링된다.
class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.loading,
    this.error,
    required this.isEmpty,
    required this.onRetry,
    required this.emptyMessage,
    required this.child,
  });

  final bool loading;
  final String? error;
  final bool isEmpty;
  final VoidCallback onRetry;
  final String emptyMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.rs(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                style: AppFonts.scaled(context, AppFonts.smallRegular)
                    .copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rh(16)),
              CupertinoButton(
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: AppFonts.scaled(context, AppFonts.bodyRegular),
          textAlign: TextAlign.center,
        ),
      );
    }

    return child;
  }
}
