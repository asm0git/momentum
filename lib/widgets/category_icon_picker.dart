import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'blurred_dialog.dart';

const categoryIconData = <String, IconData>{
  'mi_school': Icons.school,
  'mi_book': Icons.book,
  'mi_menu_book': Icons.menu_book,
  'mi_auto_stories': Icons.auto_stories,
  'mi_edit_note': Icons.edit_note,
  'mi_task_alt': Icons.task_alt,
  'mi_checklist': Icons.checklist,
  'mi_event_available': Icons.event_available,
  'mi_calendar_month': Icons.calendar_month,
  'mi_alarm': Icons.alarm,
  'mi_schedule': Icons.schedule,
  'mi_timer': Icons.timer,
  'mi_watch_later': Icons.watch_later,
  'mi_event': Icons.event,
  'mi_today': Icons.today,
  'mi_date_range': Icons.date_range,
  'mi_notifications': Icons.notifications,
  'mi_hourglass_bottom': Icons.hourglass_bottom,
  'mi_work': Icons.work,
  'mi_work_outline': Icons.work_outline,
  'mi_business': Icons.business,
  'mi_business_center': Icons.business_center,
  'mi_laptop': Icons.laptop,
  'mi_computer': Icons.computer,
  'mi_code': Icons.code,
  'mi_terminal': Icons.terminal,
  'mi_groups': Icons.groups,
  'mi_person': Icons.person,
  'mi_favorite': Icons.favorite,
  'mi_home': Icons.home,
  'mi_family_restroom': Icons.family_restroom,
  'mi_pets': Icons.pets,
  'mi_shopping_bag': Icons.shopping_bag,
  'mi_shopping_cart': Icons.shopping_cart,
  'mi_restaurant': Icons.restaurant,
  'mi_cake': Icons.cake,
  'mi_fitness_center': Icons.fitness_center,
  'mi_directions_run': Icons.directions_run,
  'mi_sports': Icons.sports,
  'mi_self_improvement': Icons.self_improvement,
  'mi_spa': Icons.spa,
  'mi_medical_services': Icons.medical_services,
  'mi_medication': Icons.medication,
  'mi_monitor_heart': Icons.monitor_heart,
  'mi_water_drop': Icons.water_drop,
  'mi_flight': Icons.flight,
  'mi_directions_car': Icons.directions_car,
  'mi_train': Icons.train,
  'mi_directions_bike': Icons.directions_bike,
  'mi_hiking': Icons.hiking,
  'mi_map': Icons.map,
  'mi_place': Icons.place,
  'mi_beach_access': Icons.beach_access,
  'mi_luggage': Icons.luggage,
  'mi_star': Icons.star,
  'mi_lightbulb': Icons.lightbulb,
  'mi_flag': Icons.flag,
  'mi_bookmark': Icons.bookmark,
  'mi_folder': Icons.folder,
  'mi_inventory_2': Icons.inventory_2,
  'mi_build': Icons.build,
  'mi_settings': Icons.settings,
  'mi_music_note': Icons.music_note,
  'mi_movie': Icons.movie,
  'mi_photo_camera': Icons.photo_camera,
  'mi_palette': Icons.palette,
  'mi_brush': Icons.brush,
  'mi_sports_esports': Icons.sports_esports,
  'mi_headphones': Icons.headphones,
  'mi_phone_iphone': Icons.phone_iphone,
  'mi_desktop_windows': Icons.desktop_windows,
  'mi_attach_file': Icons.attach_file,
  'mi_cloud': Icons.cloud,
  'mi_paid': Icons.paid,
  'mi_savings': Icons.savings,
  'mi_account_balance': Icons.account_balance,
  'mi_calculate': Icons.calculate,
  'mi_science': Icons.science,
  'mi_public': Icons.public,
  'mi_volunteer_activism': Icons.volunteer_activism,
  'mi_support_agent': Icons.support_agent,
};

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.iconName,
    required this.size,
    this.color = AppColors.primary,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final String iconName;
  final double size;
  final Color color;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final materialIcon = categoryIconData[iconName];
    if (materialIcon != null) {
      return Icon(
        materialIcon,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
      );
    }

    return Image.asset(
      'assets/img/categories/$iconName.png',
      width: size,
      height: size,
      fit: fit,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      semanticLabel: semanticLabel,
    );
  }
}

String categoryIconLabel(String name) => name
    .replaceFirst('mi_', '')
    .split('_')
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

class CategoryIconSelector extends StatelessWidget {
  const CategoryIconSelector({
    super.key,
    required this.selectedIconName,
    required this.onChanged,
  });

  final String selectedIconName;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.popup),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.popup),
        onTap: () async {
          final selected = await showBlurredDialog<String>(
            context: context,
            builder: (context) =>
                _CategoryIconGridDialog(selectedIconName: selectedIconName),
          );
          if (selected != null && context.mounted) onChanged(selected);
        },
        child: SizedBox(
          height: AppSpacing.popupFieldHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  categoryIconData[selectedIconName] ?? Icons.category,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    categoryIconLabel(selectedIconName),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.normal,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryIconGridDialog extends StatelessWidget {
  const _CategoryIconGridDialog({required this.selectedIconName});

  final String selectedIconName;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = (screenWidth - AppSpacing.md * 2)
        .clamp(0.0, 460.0)
        .toDouble();
    final gridSize = dialogWidth - AppSpacing.md * 2;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: SizedBox(
        width: dialogWidth,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose an icon',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox.square(
                dimension: gridSize,
                child: GridView.builder(
                  itemCount: categoryIconData.length,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 9,
                    crossAxisSpacing: AppSpacing.xxs,
                    mainAxisSpacing: AppSpacing.xxs,
                  ),
                  itemBuilder: (context, index) {
                    final name = categoryIconData.keys.elementAt(index);
                    final icon = categoryIconData[name]!;
                    final selected = name == selectedIconName;
                    return Material(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.focusPreset),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppRadii.focusPreset,
                        ),
                        onTap: () => Navigator.pop(context, name),
                        child: Center(
                          child: Icon(
                            icon,
                            size: 20,
                            color: selected
                                ? AppColors.onPrimary
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
