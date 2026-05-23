import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';

class SplashScreen extends StatefulWidget {
  final Map<String, dynamic>? notificationData;
  const SplashScreen({super.key, this.notificationData});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<List<ConnectivityResult>>? _onConnectivityChanged;
  late AnimationController _controller;
  late Animation _animation;
  bool _startedRouting = false;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _animation = Tween(begin: 0.0, end: 1.0).animate(_controller)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

    _controller.repeat(max: 1);
    _controller.forward();

    Get.find<ConfigController>().initSharedData();

    _startConnectivitySafeLaunch();
  }

  void _startConnectivitySafeLaunch() {
    _onConnectivityChanged = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      final bool isConnected = result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.ethernet) ||
          result.contains(ConnectivityResult.vpn);

      if (isConnected) {
        _routeOnce();
      }
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      _routeOnce();
    });
  }

  void _routeOnce() {
    if (_startedRouting) {
      return;
    }

    _startedRouting = true;

    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

    LoginHelper().handleIncomingLinks(widget.notificationData);
  }

  @override
  void dispose() {
    _controller.dispose();
    _onConnectivityChanged?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.of(context).padding.top;
    final double splashBackgroundTopOffset = safeTop > 0 ? 18 : 10;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: Theme.of(context).cardColor),
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Stack(
              alignment: AlignmentDirectional.bottomCenter,
              children: [
                Container(
                  transform: Matrix4.translationValues(
                    0,
                    320 - (320 * double.tryParse(_animation.value.toString())!),
                    0,
                  ),
                  child: Column(
                    children: [
                      Opacity(
                        opacity: _animation.value,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 120 -
                                ((120 *
                                    double.tryParse(
                                      _animation.value.toString(),
                                    )!)),
                          ),
                          child: Image.asset(Images.splashLogo, width: 220),
                        ),
                      ),
                      SizedBox(height: Get.height * 0.25),
                      Transform.translate(
                        offset: Offset(0, splashBackgroundTopOffset),
                        child: SvgPicture.asset(Images.splashSvgBackground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
