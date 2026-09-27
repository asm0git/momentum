import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/physics.dart';

import '../app_theme.dart';

class FloatingNavigationGroup extends StatefulWidget {
  const FloatingNavigationGroup({super.key});

  @override
  State<FloatingNavigationGroup> createState() =>
      _FloatingNavigationGroupState();
}

class _FloatingNavigationGroupState extends State<FloatingNavigationGroup>
  with TickerProviderStateMixin {
  static const _items = [
    _NavigationItem(name: 'Home'),
    _NavigationItem(name: 'Calendar'),
    _NavigationItem(name: 'To-Do'),
    _NavigationItem(name: 'Timer'),
    _NavigationItem(name: 'AI'),
  ];

  int _selectedIndex = 0;
  late final AnimationController _fabController = AnimationController(
    vsync: this,
    duration: AppSpacing.fabAnimationDuration,
  );
  late final AnimationController _popupController = AnimationController(
    vsync: this,
  );
  bool _isPopupOpen = false;
  bool _isPopupVisible = false;

  @override
  void dispose() {
    _fabController.dispose();
    _popupController.dispose();
    super.dispose();
  }

  void _togglePopup() {
    if (_isPopupOpen) {
      setState(() {
        _isPopupOpen = false;
      });
      _fabController.reverse();
      _hidePopup();
      return;
    }

    setState(() {
      _isPopupOpen = true;
      _isPopupVisible = true;
    });
    _fabController.forward();
    _popupController.animateWith(_popupSpring(from: 0, to: 1));
  }

  Future<void> _hidePopup() async {
    await _popupController.animateWith(_popupSpring(from: 1, to: 0));
    if (mounted) {
      setState(() {
        _isPopupVisible = false;
      });
    }
  }

  SpringSimulation _popupSpring({required double from, required double to}) {
    return SpringSimulation(
      const SpringDescription(
        mass: 1,
        stiffness: 500,
        damping: 28,
      ),
      from,
      to,
      0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        if (_isPopupVisible) ...[
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: const ColoredBox(color: AppColors.popupScrim),
            ),
          ),
          Positioned(
            left: AppSpacing.floatingGroupEdge,
            right: AppSpacing.floatingGroupEdge,
            bottom: AppSpacing.navigationDockHeight +
                AppSpacing.floatingGroupBottom +
                AppSpacing.floatingGroupGap,
            child: AnimatedBuilder(
              animation: _popupController,
              child: const SizedBox(
                height: AppSpacing.popupHeight,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadii.popup),
                      ),
                    ),
                  ),
                ),
              ),
              builder: (context, child) {
                final progress =
                    _popupController.value.clamp(0.0, 1.0).toDouble();
                return Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: 0.92 + (0.08 * progress),
                    child: child,
                  ),
                );
              },
            ),
          ),
        ],
        Positioned(
          left: AppSpacing.floatingGroupEdge,
          right: AppSpacing.floatingGroupEdge,
          bottom: AppSpacing.floatingGroupBottom,
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildNavigationDock(primary)),
                const SizedBox(width: AppSpacing.floatingGroupGap),
                _AddButton(
                  primary: primary,
                  controller: _fabController,
                  isOpen: _isPopupOpen,
                  onPressed: _togglePopup,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationDock(Color primary) {
    return Container(
      height: AppSpacing.navigationDockHeight,
      padding: const EdgeInsets.all(AppSpacing.navigationInset),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.navigationDock),
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: Row(
        children: [
          for (var index = 0; index < _items.length; index++)
            Expanded(
              child: _NavigationButton(
                item: _items[index],
                selected: index == _selectedIndex,
                primary: primary,
                onPressed: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem({required this.name});

  final String name;
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.item,
    required this.selected,
    required this.primary,
    required this.onPressed,
  });

  final _NavigationItem item;
  final bool selected;
  final Color primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = Image.asset(
      'assets/img/${selected ? 'selected' : 'unselected'}/${item.name}.png',
      width: AppSpacing.navigationIconSize,
      height: AppSpacing.navigationIconSize,
      fit: BoxFit.contain,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? primary : AppColors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.navigationItem),
      ),
      child: Center(
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          tooltip: item.name,
          icon: icon,
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.primary,
    required this.controller,
    required this.isOpen,
    required this.onPressed,
  });

  final Color primary;
  final AnimationController controller;
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Transform.rotate(
        angle: controller.value * 3.14159 * 2,
        child: child,
      ),
      child: AnimatedContainer(
        duration: AppSpacing.fabAnimationDuration,
        decoration: BoxDecoration(
          color: isOpen ? AppColors.secondary : primary,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: AppColors.popupScrim,
              blurRadius: AppSpacing.sm,
              offset: Offset(0, AppSpacing.xs),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.add, color: AppColors.onPrimary),
          iconSize: AppSpacing.addIconSize,
          padding: const EdgeInsets.all(AppSpacing.md),
          tooltip: 'Add',
        ),
      ),
    );
  }
}