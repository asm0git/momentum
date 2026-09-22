import 'package:flutter/material.dart';
import '../../models/category.dart';

/// The small colored icon badge representing a category - reused on
/// Dashboard cards, To-Do rows, AI Planner, and the New Event/Task
/// form. Since Category is a shared model, this is the only widget
/// that needs to know how to draw one.
class CategoryChip extends StatelessWidget {
  final TaskCategory category;
  final double size;

  const CategoryChip({super.key, required this.category, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: category.color,
      child: Icon(category.icon, color: Colors.white, size: size * 0.55),
    );
  }
}
