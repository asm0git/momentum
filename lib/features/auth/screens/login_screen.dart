import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bottom_nav_shell.dart';
import 'add_calendars_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.bolt, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'MOMENTUM',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.primary, letterSpacing: 1.2),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AddCalendarsScreen(
                        onDone: () {
                          // Auth/onboarding is done - drop the whole
                          // auth stack and land on the main app shell.
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const RootShell()),
                            (route) => false,
                          );
                        },
                      ),
                    ));
                  },
                  child: const Text('Get started', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
