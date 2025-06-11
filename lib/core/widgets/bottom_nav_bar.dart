import 'package:flutter/material.dart';

class ShopUBBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool floating;
  const ShopUBBottomNavBar(
      {super.key, required this.currentIndex, this.floating = false});

  void _onTap(BuildContext context, int index) {
    const routes = ['/home', '/search', '/orders'];
    if (index != currentIndex) {
      Navigator.pushReplacementNamed(context, routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      margin: floating
          ? const EdgeInsets.only(left: 24, right: 24, bottom: 16)
          : EdgeInsets.zero,
      decoration: floating
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            )
          : null,
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: floating ? Colors.transparent : Colors.white,
        elevation: floating ? 0 : 8,
        currentIndex: currentIndex,
        onTap: (i) => _onTap(context, i),
        selectedItemColor: const Color(0xFF7B61FF),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Orders'),
        ],
      ),
    );
    return floating
        ? Stack(
            children: [
              const SizedBox(height: 70),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: bar,
              ),
            ],
          )
        : bar;
  }
}
