import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  // Brand Colors
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);
  static const Color lightGrey = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // --- APP BAR ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconButton(Icons.grid_view_rounded),
                  Image.asset('lib/assets/images/logo1.png', height: 45),
                  _buildIconButton(Icons.notifications_none_rounded),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // --- WELCOME TEXT ---
              const Text(
                "Admin Console",
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.w800, 
                  color: wellGreen,
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                "Manage your WellNest community",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              
              const SizedBox(height: 25),

              // --- SEARCH BAR ---
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: accentYellow.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search content...",
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: wellGreen),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: accentYellow, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: nestOrange, width: 2),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),

              // --- STATISTICS ---
              Row(
                children: [
                  Expanded(child: _buildModernStatCard("Users", "15", Icons.people_alt_rounded)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildModernStatCard("Recipes", "34", Icons.restaurant_menu_rounded)),
                ],
              ),
              
              const SizedBox(height: 30),

              // --- MANAGEMENT TABLE ---
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: accentYellow,
                  borderRadius: BorderRadius.circular(35),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentYellow, accentYellow.withOpacity(0.8)],
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Activity',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: wellGreen),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.tune_rounded, size: 20, color: wellGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildModernTableRow("New Salad Recipe Posted", "2m ago"),
                    _buildModernTableRow("User 'ChefMike' joined", "1h ago"),
                    _buildModernTableRow("Spam comment removed", "3h ago"),
                    _buildModernTableRow("Database backup sync", "5h ago"),
                    const SizedBox(height: 10),
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

  // --- HELPER METHODS (Placed inside the class) ---

  Widget _buildIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: lightGrey,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: nestOrange, size: 28),
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: lightGrey),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: nestOrange, size: 30),
          const SizedBox(height: 15),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: wellGreen)),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildModernTableRow(String title, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: wellGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.history, size: 18, color: wellGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.delete_sweep_rounded, color: nestOrange, size: 22),
        ],
      ),
    );
  }
} // This is the last closing brace for the AdminDashboard class