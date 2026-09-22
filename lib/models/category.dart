import 'package:flutter/material.dart';

/// A first-class shared model representing a task/event category
/// (Work, Personal, School, ...). Every screen that shows a category
/// icon or color (Dashboard cards, To-Do groups, the New Event/Task
/// form) reads from the SAME list below, so the icon/color logic for
/// a category only ever lives in one place.
class TaskCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const TaskCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// The categories shown in the mockup. Add, rename or recolor freely -
/// every screen updates automatically since they all read this list
/// via AppData.categories.
final List<TaskCategory> defaultCategories = [
  const TaskCategory(
    id: 'work',
    name: 'Work',
    icon: Icons.work,
    color: Color(0xFF2B1B4E),
  ),
  const TaskCategory(
    id: 'personal',
    name: 'Personal',
    icon: Icons.person,
    color: Color(0xFFE0245E),
  ),
  const TaskCategory(
    id: 'school',
    name: 'School',
    icon: Icons.school,
    color: Color(0xFF6A4C93),
  ),
];
