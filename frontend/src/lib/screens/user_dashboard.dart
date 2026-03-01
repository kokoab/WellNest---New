import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:my_app/screens/custom_bottom_nav.dart'; 
import 'package:my_app/screens/profile_page.dart';
import 'feed_page.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0; 

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const RecipeGridView(), 
      const FeedPage(),
      const ProfilePage(),
    ];
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true, // Allows the floating nav bar to look transparent at the edges
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Swaps the visible page and updates the nav UI
          });
        },
      ),
    );
  }
}

// --- PART A: THE RECIPE GRID VIEW WITH EXPANSION ---
class RecipeGridView extends StatefulWidget {
  const RecipeGridView({super.key});

  @override
  State<RecipeGridView> createState() => _RecipeGridViewState();
}

class _RecipeGridViewState extends State<RecipeGridView> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);

  List<int> recipeRatings = [0, 0, 0, 0, 0, 0];
  
  // Track which card is expanded (-1 means none)
  int expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.menu, color: nestOrange, size: 35),
                Image.asset('lib/assets/images/logo1.png', height: 50),
                const Icon(Icons.notifications, color: nestOrange, size: 35),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                suffixIcon: const Icon(Icons.search, color: wellGreen),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: accentYellow, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Discover',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: wellGreen),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                itemCount: 6,
                itemBuilder: (context, index) {
                  final bool isGreen = (index % 3 == 1) || (index == 5);
                  return _buildRecipeCard(
                    index,
                    isGreen ? wellGreen : accentYellow,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(int index, Color bgColor) {
    bool isExpanded = expandedIndex == index;
    
    // Dynamic height logic
    double normalHeight = index.isEven ? 200 : 260;
    double expandedHeight = 380; 

    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle expansion
          expandedIndex = isExpanded ? -1 : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        height: isExpanded ? expandedHeight : normalHeight,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset(
                  'lib/assets/images/recipe${index + 1}.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            
            // Revealed Content when Expanded
            if (isExpanded) ...[
              const SizedBox(height: 12),
              const Text(
                "Special Healthy Bowl",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                "Prep: 20 mins | Calories: 350",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 8),
            
            // Star Ratings
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (starIndex) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      recipeRatings[index] = starIndex + 1;
                    });
                  },
                  child: Icon(
                    Icons.star,
                    size: 18,
                    color: starIndex < recipeRatings[index] ? Colors.yellowAccent : Colors.white70,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}