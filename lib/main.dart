// This is your app. It runs as it is: press run and you get the screen below.
//
// Nothing here is precious. Change the title, change the colors, delete the
// counter, add your own screens. It exists so that the repository is a working
// Flutter app from minute one instead of an empty folder.
//
// Everything in this file is Module 4 and 5 material: StatelessWidget,
// StatefulWidget, setState, Scaffold, AppBar, Column, Card, FilledButton.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'widgets/bottom_navigation_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Final Project',
      debugShowCheckedModeBanner: false,

      theme: appTheme,

      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: AppSpacing.appBarHeight,
        title: Text(
          'Dashboard',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppRadii.appBarBottom),
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: const Stack(
        children: [
          SizedBox.expand(),
          Positioned.fill(
            child: FloatingNavigationGroup(),
          ),
        ],
      ),
    );
  }
}