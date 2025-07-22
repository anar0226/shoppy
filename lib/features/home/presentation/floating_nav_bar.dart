import 'package:flutter/material.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width / 2.2;
    return Center(
      child: Container(
        width: width,
        height: 50,
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(context, Icons.home, 0),
            _buildNavItem(context, Icons.search, 1),
            _buildNavItem(context, Icons.receipt_long, 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, int index) {
    final isActive = currentIndex == index;
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? const Color(0xFF7B61FF) : Colors.black54,
        size: 28,
      ),
      onPressed: () => onTap(index),
    );
  }
}
