import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../cart/providers/cart_provider.dart';
import 'cart_bottom_sheet.dart';

class CartButton extends StatefulWidget {
  const CartButton({super.key});

  @override
  State<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<CartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shakeAnim;
  late final CartProvider? _cartProv;
  bool _hasProvider = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.3, end: 0.3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.0), weight: 1),
    ]).animate(_controller);

    try {
      _cartProv = Provider.of<CartProvider>(context, listen: false);
      _hasProvider = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cartProv?.setShakeController(_controller);
      });
    } catch (_) {
      _cartProv = null;
    }
  }

  @override
  void dispose() {
    if (_hasProvider) {
      _cartProv?.setShakeController(null);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (_, cart, __) {
        if (cart.totalQuantity == 0) {
          return const SizedBox.shrink();
        }
        return AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) {
            return Transform.rotate(
              angle: _shakeAnim.value,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () => _openCartSheet(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset('assets/images/icons/cart.png'),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.deepPurple, shape: BoxShape.circle),
                    child: Text('${cart.totalQuantity}',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const CartBottomSheet(),
    );
  }
}
