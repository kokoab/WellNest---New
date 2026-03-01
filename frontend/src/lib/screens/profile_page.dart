import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // Brand Colors
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // --- TOP BAR ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.menu, color: nestOrange, size: 35),
                Image.asset('lib/assets/images/logo1.png', height: 50),
                const Icon(Icons.notifications, color: nestOrange, size: 35),
              ],
            ),
            const SizedBox(height: 30),

            // --- USER AVATAR ---
            const CircleAvatar(
              radius: 60,
              backgroundImage: AssetImage('lib/assets/images/user_john.png'),
            ),
            const SizedBox(height: 10),
            const Text(
              'John',
              style: TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.bold, 
                color: wellGreen
              ),
            ),
            const SizedBox(height: 20),

            // --- STATISTICS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatColumn("12", "Recipes"),
                const SizedBox(width: 40),
                _buildStatColumn("13", "Posts"),
              ],
            ),
            const SizedBox(height: 30),

            // --- ACTION BUTTON ---
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: wellGreen, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text(
                'Add new Recipe',
                style: TextStyle(color: accentYellow, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),

            // --- MY RECIPES SECTION ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'My Recipe',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: wellGreen),
              ),
            ),
            const SizedBox(height: 20),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRecipeMiniCard(wellGreen),
                  const SizedBox(width: 15),
                  _buildRecipeMiniCard(accentYellow),
                  const SizedBox(width: 15),
                  _buildRecipeMiniCard(wellGreen),
                ],
              ),
            ),
            const SizedBox(height: 100), // Space for Bottom Nav
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: wellGreen),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildRecipeMiniCard(Color bgColor) {
    return Container(
      width: 160,
      height: 180,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                'lib/assets/images/recipe1.png', // Replace with your asset
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, size: 14, color: accentYellow),
              Icon(Icons.star, size: 14, color: accentYellow),
              Icon(Icons.star, size: 14, color: accentYellow),
              Icon(Icons.star, size: 14, color: accentYellow),
              Icon(Icons.star, size: 14, color: accentYellow),
            ],
          ),
        ],
      ),
    );
  }
}