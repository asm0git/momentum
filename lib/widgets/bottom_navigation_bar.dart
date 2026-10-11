import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';
import 'add_item_popup.dart';
import 'add_task_button.dart';
import 'blurred_dialog.dart';

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
    duration: const Duration(milliseconds: 340),
    reverseDuration: const Duration(milliseconds: 320),
  );
  late final CurvedAnimation _popupAnimation = CurvedAnimation(
    parent: _popupController,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  bool _isPopupOpen = false;
  bool _isPopupVisible = false;

  @override
  void dispose() {
    _popupAnimation.dispose();
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
    _popupController.forward();
  }

  void _closePopup() {
    if (!_isPopupOpen) return;
    setState(() => _isPopupOpen = false);
    _fabController.reverse();
    _hidePopup();
  }

  Future<void> _hidePopup() async {
    await _popupController.reverse();
    if (mounted && !_isPopupOpen) {
      _overlayController.hide();
      setState(() {
        _isPopupVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _buildNavigationGroup(primary, showPopup: true),
      ),
      child: _isPopupVisible
          ? const SizedBox.expand()
          : _buildNavigationGroup(primary, showPopup: false),
    );
  }

  Widget _buildNavigationGroup(Color primary, {required bool showPopup}) {
    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    final bottomOffset = safeAreaBottom > AppSpacing.floatingGroupBottom
        ? safeAreaBottom
        : AppSpacing.floatingGroupBottom;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height:
              AppSpacing.navigationDockHeight +
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
            child: AnimatedBuilder(
              animation: _popupAnimation,
              builder: (context, child) =>
                  Opacity(opacity: _popupAnimation.value, child: child),
              child: const BlurredPopupBarrier(
                key: ValueKey('add-item-backdrop'),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.floatingGroupEdge,
            right: AppSpacing.floatingGroupEdge,
            bottom:
                AppSpacing.navigationDockHeight +
                bottomOffset +
                AppSpacing.floatingGroupGap,
            child: AnimatedBuilder(
              animation: _popupAnimation,
              child: AddItemPopup(
                key: const ValueKey('add-item-popup'),
                onSaved: (_) => _closePopup(),
                onCancel: _closePopup,
              ),
              builder: (context, child) {
                return FadeTransition(
                  opacity: _popupAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(_popupAnimation),
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
          bottom: bottomOffset,
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
                  Navigator.of(
                    context,
                  ).pushReplacementNamed(_items[index].route);
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
    final icon = item == AppDestination.insights
        ? Icon(
            selected ? Icons.insights : Icons.insights_outlined,
            size: AppSpacing.navigationIconSize,
            color: selected ? AppColors.onPrimary : primary,
          )
        : Image.asset(
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
