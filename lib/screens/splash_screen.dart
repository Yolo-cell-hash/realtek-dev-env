import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:vdb_realtek/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);


    return FlutterSplashScreen.fadeIn(
      backgroundColor: theme.scaffoldBackgroundColor,
      duration: Duration(seconds: 5),
      onInit: () {
        debugPrint("On Init");
      },
      onEnd: () {
        debugPrint("On End");
      },
      childWidget: SvgPicture.asset(
        'images/logo.svg',
        height: 100,
      ),
      onAnimationEnd: () => debugPrint("On Fade Ins End"),
      nextScreen: OnboardingScreen(),
    );
  }
}