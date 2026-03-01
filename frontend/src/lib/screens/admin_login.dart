import 'package:flutter/material.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  // BACKEND DEV: Use these controllers to get the text for the API request
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    const Color wellGreen = Color(0xFF097333);
    const Color nestOrange = Color(0xFFEF5026);
    const Color accentYellow = Color(0xFFFDB813);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Admin Login",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Image.asset(
                  'lib/assets/images/logo1.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(text: 'well', style: TextStyle(color: wellGreen)),
                      TextSpan(text: 'nest', style: TextStyle(color: nestOrange)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
              
              const Text("Username:", style: TextStyle(color: wellGreen, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              // BACKEND DEV: Controller added here
              _buildTextField(_usernameController, accentYellow),
              
              const SizedBox(height: 24),
              
              const Text("Password:", style: TextStyle(color: wellGreen, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              // BACKEND DEV: Controller added here
              _buildTextField(_passwordController, accentYellow, obscureText: true),
              
              const SizedBox(height: 32),
              
              Align(
                alignment: Alignment.centerRight,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: wellGreen)
                  : OutlinedButton(
                      onPressed: () {
                        // BACKEND DEV: Trigger your login logic here
                        setState(() => _isLoading = true);
                        print("Logging in with: ${_usernameController.text}");
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: wellGreen, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      ),
                      child: const Text('Enter', style: TextStyle(color: accentYellow, fontWeight: FontWeight.bold)),
                    ),
              ),
              
              const SizedBox(height: 100),
              
              Center(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: wellGreen, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                  ),
                  child: const Text(
                    'User Login',
                    style: TextStyle(color: accentYellow, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Adjusted helper to accept a controller
  Widget _buildTextField(TextEditingController controller, Color borderColor, {bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: borderColor),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}