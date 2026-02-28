import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  // Brand Colors matching your design
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
              const SizedBox(height: 20),

              // --- SEARCH BAR ---
              TextField(
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.search, color: wellGreen),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: accentYellow, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- STATISTICS CARDS ---
              Row(
                children: [
                  Expanded(child: _buildStatCard("15 Users")),
                  const SizedBox(width: 15),
                  Expanded(child: _buildStatCard("34 Recipes")),
                ],
              ),
              const SizedBox(height: 30),

              // --- DATA TABLE SECTION ---
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: accentYellow,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
                  ],
                ),
                padding: const EdgeInsets.all(25),
                child: Column(
                  children: [
                    const Text(
                      'Table',
                      style: TextStyle(
                        fontSize: 22, 
                        fontWeight: FontWeight.bold, 
                        color: wellGreen
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Generated Table Rows
                    _buildTableRow("User Content Example 1"),
                    _buildTableRow("User Content Example 2"),
                    _buildTableRow("User Content Example 3"),
                    _buildTableRow("User Content Example 4"),
                    _buildTableRow("User Content Example 5"),
                    _buildTableRow("User Content Example 6"),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for "15 Users" and "34 Recipes" boxes
  Widget _buildStatCard(String label) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: accentYellow,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18, 
          fontWeight: FontWeight.bold, 
          color: wellGreen
        ),
      ),
    );
  }

  // Helper for the rows inside the Table
  Widget _buildTableRow(String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 25,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              // content could be dynamic from backend
            ),
          ),
          const SizedBox(width: 15),
          const Icon(Icons.delete, color: Colors.black, size: 24),
        ],
      ),
    );
  }
}