import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'category_icon_picker.dart';

class SelectorOption {
  const SelectorOption({required this.label, this.value, this.iconName});

  final String? value;
  final String label;
  final String? iconName;
}

class Selector extends StatelessWidget {
  const Selector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.placeholder,
    required this.onChanged,
    this.alignment = AlignmentDirectional.centerStart,
    this.isExpanded = false,
    this.contentColor = AppColors.primary,
  });

  final List<SelectorOption> options;
  final String? selectedValue;
  final String placeholder;
  final ValueChanged<String?> onChanged;
  final AlignmentGeometry alignment;
  final bool isExpanded;
  final Color contentColor;

  Widget _optionContent(
    SelectorOption option,
    TextStyle style, {
    required String label,
  }) {
    final iconName = option.iconName;
    final labelWidget = Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (iconName == null || iconName.trim().isEmpty) return labelWidget;

    return Row(
      children: [
        CategoryIcon(iconName: iconName, size: 18, color: contentColor),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: labelWidget),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.normal,
      color: contentColor,
    );
    final placeholderStyle = style.copyWith(
      color: AppColors.onSurface.withValues(alpha: 0.55),
    );

    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: selectedValue,
        isDense: true,
        isExpanded: isExpanded,
        alignment: alignment,
        borderRadius: BorderRadius.circular(AppRadii.popup),
        dropdownColor: AppColors.surface,
        selectedItemBuilder: (context) => [
          for (final option in options)
            Align(
              alignment: Alignment.centerLeft,
              child: option.value == null
                  ? Text(placeholder, style: placeholderStyle)
                  : _optionContent(option, style, label: option.label),
            ),
        ],
        icon: const Icon(
          Icons.unfold_more_rounded,
          size: 18,
          color: AppColors.primary,
        ),
        style: style,
        hint: Text(placeholder, style: placeholderStyle),
        items: [
          for (final option in options)
            DropdownMenuItem<String?>(
              value: option.value,
              child: _optionContent(option, style, label: option.label),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
