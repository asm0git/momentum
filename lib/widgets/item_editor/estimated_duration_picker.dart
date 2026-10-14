import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../blurred_dialog.dart';

class EstimatedDurationPicker extends StatelessWidget {
  const EstimatedDurationPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Estimated duration',
  });

  final Duration value;
  final ValueChanged<Duration> onChanged;
  final String label;

  Future<void> _showPicker(BuildContext context) async {
    final duration = await showBlurredDialog<Duration>(
      context: context,
      builder: (_) =>
          _EstimatedDurationDialog(initialDuration: value, title: label),
    );
    if (duration != null) onChanged(duration);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.normal,
      color: AppColors.onSurface,
    );
    final radius = BorderRadius.circular(AppRadii.estimatedDuration);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => _showPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          child: SizedBox(
            height: AppSpacing.popupFieldHeight,
            child: Row(
              children: [
                Expanded(child: Text(label, style: textStyle)),
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadii.focusPreset),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatDuration(value), style: textStyle),
                      const SizedBox(width: AppSpacing.xxs),
                      const Icon(
                        Icons.unfold_more_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EstimatedDurationDialog extends StatefulWidget {
  const _EstimatedDurationDialog({
    required this.initialDuration,
    required this.title,
  });

  final Duration initialDuration;
  final String title;

  @override
  State<_EstimatedDurationDialog> createState() =>
      _EstimatedDurationDialogState();
}

class _EstimatedDurationDialogState extends State<_EstimatedDurationDialog> {
  late final FixedExtentScrollController _hoursController;
  late final FixedExtentScrollController _minutesController;
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialDuration.inHours.clamp(0, 23).toInt();
    _minutes =
        ((widget.initialDuration.inMinutes % 60) / 5)
            .round()
            .clamp(0, 11)
            .toInt() *
        5;
    _hoursController = FixedExtentScrollController(initialItem: _hours);
    _minutesController = FixedExtentScrollController(
      initialItem: _minutes ~/ 5,
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.normal,
      color: AppColors.onSurface,
    );
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: AppColors.onSurface);

    return Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: titleStyle),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: 240,
              height: 128,
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          child: CupertinoPicker.builder(
                            itemExtent: 36,
                            scrollController: _hoursController,
                            childCount: 24,
                            onSelectedItemChanged: (value) =>
                                setState(() => _hours = value),
                            itemBuilder: (context, value) =>
                                Center(child: Text('$value', style: textStyle)),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text('hours', style: textStyle),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          child: CupertinoPicker.builder(
                            itemExtent: 36,
                            scrollController: _minutesController,
                            childCount: 12,
                            onSelectedItemChanged: (value) =>
                                setState(() => _minutes = value * 5),
                            itemBuilder: (context, value) => Center(
                              child: Text('${value * 5}', style: textStyle),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text('mins', style: textStyle),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 48),
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(Duration(hours: _hours, minutes: _minutes)),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
