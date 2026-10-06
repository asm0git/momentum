import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/physics.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';
import 'add_item_popup.dart';
import 'add_task_button.dart';

// Bottom navigation dock, add-task button, and expandable popup overlay.
class FloatingNavigationGroup extends StatefulWidget {
  const FloatingNavigationGroup({super.key, required this.selectedIndex});

  final int selectedIndex;

  @override
  State<FloatingNavigationGroup> createState() =>
      _FloatingNavigationGroupState();
}

class _FloatingNavigationGroupState extends State<FloatingNavigationGroup>
    with TickerProviderStateMixin {
  static const _items = AppDestination.values;
  final _overlayController = OverlayPortalController();
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
    _overlayController.show();
    _fabController.forward();
    _popupController.animateWith(_popupSpring(from: 0, to: 1));
  }

  Future<void> _hidePopup() async {
    await _popupController.animateWith(_popupSpring(from: 1, to: 0));
    if (mounted && !_isPopupOpen) {
      _overlayController.hide();
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

    return OverlayPortal.targetsRootOverlay(
      controller: _overlayController,
      overlayChildBuilder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _buildNavigationGroup(primary, showPopup: true),
      ),
      child: _isPopupVisible
          ? const SizedBox.expand()
          : _buildNavigationGroup(primary, showPopup: false),
    );
  }

  Widget _buildNavigationGroup(Color primary, {required bool showPopup}) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: AppSpacing.navigationDockHeight +
              AppSpacing.floatingGroupBottom +
              AppSpacing.sectionGap,
          child: ClipRect(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.navigationBlurMaskStart,
                    AppColors.navigationBlurMaskEnd,
                  ],
                ).createShader(bounds);
              },
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: const SizedBox.expand(
                  child: ColoredBox(color: AppColors.navigationBlurTint),
                ),
              ),
            ),
          ),
        ),
        if (showPopup) ...[
          Positioned.fill(
            child: BackdropFilter(
              key: const ValueKey('add-item-backdrop'),
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
              child: const AddItemPopup(
                key: ValueKey('add-item-popup'),
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
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildNavigationDock(primary)),
                const SizedBox(width: AppSpacing.floatingGroupGap),
                AddTaskButton(
                  key: ValueKey('add-task-button-${widget.selectedIndex}'),
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
                key: ValueKey(_items[index].route),
                item: _items[index],
                selected: index == widget.selectedIndex,
                primary: primary,
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(
                    _items[index].route,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Individual destination button inside the floating navigation dock.
class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    super.key,
    required this.item,
    required this.selected,
    required this.primary,
    required this.onPressed,
  });

  final AppDestination item;
  final bool selected;
  final Color primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = Image.asset(
      'assets/img/${selected ? 'selected' : 'unselected'}/${item.iconName}.png',
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
