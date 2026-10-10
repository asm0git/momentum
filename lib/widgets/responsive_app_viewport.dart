import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Keeps the web app in a phone-sized viewport on wide browser windows.
/// On phones and device emulators, the app uses the full available screen.
class ResponsiveAppViewport extends StatelessWidget {
  const ResponsiveAppViewport({super.key, required this.child});

  final Widget child;

  static const _phoneWidth = 430.0;
  static const _phoneHeight = 900.0;
  static const _wideScreenBreakpoint = 600.0;
  static const _wideScreenGutter = 24.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : mediaQuery.size.width;
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : mediaQuery.size.height;
        final usePhoneFrame = availableWidth > _wideScreenBreakpoint;

        final appHeight = (usePhoneFrame
                ? math.min(
                    _phoneHeight,
                    math.max(0, availableHeight - _wideScreenGutter * 2),
                  )
                : availableHeight)
            .toDouble();
        final appWidth = (usePhoneFrame
                ? math.min(
                    _phoneWidth,
                    math.min(
                      availableWidth - _wideScreenGutter * 2,
                      appHeight * _phoneWidth / _phoneHeight,
                    ),
                  )
                : math.min(_phoneWidth, availableWidth))
            .toDouble();
        final appSize = Size(appWidth, appHeight);
        final app = MediaQuery(
          data: mediaQuery.copyWith(size: appSize),
          child: SizedBox.fromSize(size: appSize, child: child),
        );

        return ColoredBox(
          color: usePhoneFrame ? AppColors.surface : AppColors.background,
          child: Center(
            child: ClipRRect(
              borderRadius: usePhoneFrame
                  ? BorderRadius.circular(AppRadii.popup)
                  : BorderRadius.zero,
              child: app,
            ),
          ),
        );
      },
    );
  }
}
