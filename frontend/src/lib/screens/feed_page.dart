import 'package:flutter/material.dart';
import 'package:my_app/config/app_config.dart';
import 'package:my_app/models/post.dart';
import 'package:my_app/services/api_service.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ApiService _apiService = ApiService();
  late Future<List<Post>> _postsFuture;

  @override
  void initState() {
    super.initState();
    // Load the data as soon as the page opens
    _postsFuture = _apiService.fetchPosts();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Post>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF097333)));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No posts found."));
          }

          final posts = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Your search bar and header code here...
                
                // --- DYNAMIC FEED LIST ---
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return _buildFeedCard(posts[index]);
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  // Updated BuildCard to accept a Post object
  Widget _buildFeedCard(Post post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDB813),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 5),
          Text(post.content),
          const SizedBox(height: 15),
          // Using Network Image since it's coming from the backend
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              post.imageUrl, 
              height: 180, 
              width: double.infinity, 
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey, height: 180),
            ),
          ),
          // ... rest of your interaction bar code
        ],
      ),
    );
  }
}