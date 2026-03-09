import 'package:flutter/material.dart';
import 'package:vdb_realtek/widgets/login_form.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);


    return Scaffold(
      backgroundColor:theme.scaffoldBackgroundColor,
      body:LoginForm()
    );
  }
}
