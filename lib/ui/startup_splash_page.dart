import 'dart:async';

import 'package:flutter/material.dart';

class StartupSplashPage extends StatefulWidget {
  const StartupSplashPage({super.key, required this.child});

  final Widget child;

  @override
  State<StartupSplashPage> createState() => _StartupSplashPageState();
}

class _StartupSplashPageState extends State<StartupSplashPage> {
  static const _duration = Duration(seconds: 10);

  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_duration, () {
      if (mounted) {
        setState(() => _finished = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _finished
          ? widget.child
          : const _DevVoidSplash(key: ValueKey('devvoid-splash')),
    );
  }
}

class _DevVoidSplash extends StatelessWidget {
  const _DevVoidSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(18, 28, 18, 96),
              child: Center(
                child: Image(
                  image: AssetImage('assets/startup/devvoid_splash.png'),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned(
              left: 72,
              right: 72,
              bottom: 36,
              child: _SplashProgressBar(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashProgressBar extends StatelessWidget {
  const _SplashProgressBar();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _StartupSplashPageState._duration,
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 3,
            backgroundColor: Colors.white10,
            color: Colors.white.withAlpha(185),
          ),
        );
      },
    );
  }
}
