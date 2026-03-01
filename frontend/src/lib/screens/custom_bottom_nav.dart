import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const Color wellGreen = Color(0xFF097333);
  static const Color accentYellow = Color(0xFFFDB813);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: wellGreen, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem('Recipe', 0),
          _navItem('Feed', 1),
          _navItem('Profile', 2),
        ],
      ),
    );
  }

  Widget _navItem(String label, int index) {
    final bool active = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index), 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: active 
            ? BoxDecoration(
                border: Border.all(color: accentYellow, width: 1),
                borderRadius: BorderRadius.circular(20),
              ) 
            : null,
        child: Text(
          label,
          style: const TextStyle(
            color: wellGreen, 
            fontWeight: FontWeight.bold, 
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}