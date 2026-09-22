import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AddCalendarsScreen extends StatelessWidget {
  final VoidCallback onDone;

  const AddCalendarsScreen({super.key, required this.onDone});

  static const _providers = [
    ('Google Calendar', Icons.calendar_today),
    ('Outlook', Icons.email),
    ('Canvas', Icons.school),
    ('iOS Calendar', Icons.phone_iphone),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: _providers.map((p) {
                    return ListTile(
                      leading: Icon(p.$2, color: AppColors.primary),
                      title: Text(p.$1),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: wire up to lib/services/calendar_integrations/*
                        // (one adapter per provider: Google, Outlook, Canvas, iOS)
                      },
                    );
                  }).toList(),
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 2,
                  onPressed: onDone,
                  child: const Icon(Icons.check),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
