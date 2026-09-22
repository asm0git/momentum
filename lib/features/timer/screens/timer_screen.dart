import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/app_data.dart';
import '../../../models/pomodoro_preset.dart';

class TimerScreen extends StatefulWidget {
  final AppData appData;

  const TimerScreen({super.key, required this.appData});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  PomodoroPreset _selected = defaultPomodoroPresets.first;
  late Duration _remaining = _selected.focusDuration;
  Timer? _ticker;
  bool _running = false;

  void _selectPreset(PomodoroPreset preset) {
    _ticker?.cancel();
    setState(() {
      _selected = preset;
      _remaining = preset.focusDuration;
      _running = false;
    });
  }

  void _toggleRunning() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining.inSeconds <= 0) {
        t.cancel();
        setState(() => _running = false);
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _display {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final dueToday = widget.appData.dueToday;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 90,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.primary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          flexibleSpace: const FlexibleSpaceBar(
            title: Text('Pomodoro',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: defaultPomodoroPresets.map((p) {
                  final selected = p.id == _selected.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ChoiceChip(
                      label: Text('${p.focusDuration.inMinutes} min'),
                      selected: selected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark),
                      onSelected: (_) => _selectPreset(p),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 6),
                  ),
                  child: Text(_display, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                  ),
                  onPressed: _toggleRunning,
                  child: Icon(_running ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 40),
              const Text('Due Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              ...dueToday.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SectionCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.title),
                        subtitle: Text(t.category.name),
                      ),
                    ),
                  )),
            ]),
          ),
        ),
      ],
    );
  }
}
