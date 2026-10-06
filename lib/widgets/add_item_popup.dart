import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';

enum _PopupItemType { event, task }

class AddItemPopup extends StatefulWidget {
  const AddItemPopup({super.key});

  @override
  State<AddItemPopup> createState() => _AddItemPopupState();
}

class _AddItemPopupState extends State<AddItemPopup> {
  _PopupItemType _selectedType = _PopupItemType.event;
  final _titleController = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.popup),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ItemTypeSelector(
              selectedType: _selectedType,
              onTypeChanged: (type) => setState(() => _selectedType = type),
            ),
            const SizedBox(height: AppSpacing.sm),
            _TitleCategoryFields(
              titleController: _titleController,
              selectedCategory: _selectedCategory,
              onCategoryChanged: (category) =>
                  setState(() => _selectedCategory = category),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleCategoryFields extends StatelessWidget {
  const _TitleCategoryFields({
    required this.titleController,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final TextEditingController titleController;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fieldStyle = textTheme.bodySmall?.copyWith(
      color: AppColors.onSurface.withValues(alpha: 0.55),
    );
    final categories = mockCategories.map((category) => category.title);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: TextField(
                controller: titleController,
                style: fieldStyle,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: fieldStyle,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.onSurface.withValues(alpha: 0.12),
            ),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Text('Category', style: fieldStyle),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedCategory,
                        isExpanded: true,
                        alignment: AlignmentDirectional.centerEnd,
                        icon: Icon(
                          Icons.unfold_more_rounded,
                          size: 18,
                          color: AppColors.onSurface.withValues(alpha: 0.55),
                        ),
                        style: fieldStyle,
                        hint: Text('None', style: fieldStyle),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None', style: fieldStyle),
                          ),
                          for (final category in categories)
                            DropdownMenuItem<String?>(
                              value: category,
                              child: Text(category, style: fieldStyle),
                            ),
                        ],
                        onChanged: onCategoryChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTypeSelector extends StatelessWidget {
  const _ItemTypeSelector({
    required this.selectedType,
    required this.onTypeChanged,
  });

  final _PopupItemType selectedType;
  final ValueChanged<_PopupItemType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.surface),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          for (final type in _PopupItemType.values)
            Expanded(
              child: Material(
                color: type == selectedType
                    ? AppColors.primary
                    : AppColors.transparent,
                borderRadius: BorderRadius.circular(100),
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () => onTypeChanged(type),
                  child: Center(
                    child: Text(
                      type == _PopupItemType.event ? 'Event' : 'Task',
                      style: textTheme.bodyMedium?.copyWith(
                        color: type == selectedType
                            ? AppColors.onPrimary
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
