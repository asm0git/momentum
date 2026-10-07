import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_theme.dart';

const _popupBlurSigma = 8.0;

class BlurredPopupBarrier extends StatelessWidget {
  const BlurredPopupBarrier({super.key});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: _popupBlurSigma,
        sigmaY: _popupBlurSigma,
      ),
      child: const ColoredBox(color: AppColors.popupScrim),
    );
  }
}

Future<T?> showBlurredDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppColors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) => Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: BlurredPopupBarrier()),
        ),
        Center(child: Builder(builder: builder)),
      ],
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return FadeTransition(opacity: curvedAnimation, child: child);
    },
  );
}
