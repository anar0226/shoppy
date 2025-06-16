import 'package:flutter/material.dart';
import 'floating_nav_bar.dart';
import 'package:shoppy/features/cart/presentation/cart_button.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final bool showBackButton;
  final VoidCallback? onBack;

  const MainScaffold({
    Key? key,
    required this.child,
    required this.currentIndex,
    this.showBackButton = false,
    this.onBack,
  }) : super(key: key);

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/search');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/orders');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (showBackButton)
          Positioned(
            left: 16,
            bottom: 25,
            child: GestureDetector(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black87),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FloatingNavBar(
            currentIndex: currentIndex,
            onTap: (i) => _onNavTap(context, i),
          ),
        ),
        // Cart button bottom right
        const Positioned(
          right: 16,
          bottom: 25,
          child: CartButton(),
        ),
      ],
    );
  }
}
