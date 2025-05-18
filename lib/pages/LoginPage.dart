import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart'; // Make sure MainMenu is imported here
// Import the new ResetPassword page
import 'resetpassword.dart'; // Assuming your file is named resetpassword.dart and the class is ResetPassword


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(); // Added for sign up
  bool _isLoading = false;
  bool _isSignUp = false; // Track whether it's login or sign up

  // Dispose controllers when the widget is removed
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose(); // Dispose the new controller.
    super.dispose();
  }

  Future<void> _loginOrSignUp(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    // Get username only if signing up, trim whitespace
    final username = _isSignUp ? _usernameController.text.trim() : '';

    // Basic validation for required fields
    if (email.isEmpty || password.isEmpty || (_isSignUp && username.isEmpty)) {
      _showErrorDialog(context, 'Please fill in all fields');
      return; // Exit if validation fails
    }

    // Set loading state to true
    setState(() => _isLoading = true);

    try {
      // Determine the API endpoint based on whether it's login or signup
      final String apiUrl = _isSignUp ? 'http://192.168.1.2:3000/register' : 'http://10.0.2.2:3000/login';

      // Prepare the request body based on the operation
      final Map<String, String> body = _isSignUp
          ? { // Body for registration
              'email': email,
              'password': password,
              'username': username,
            }
          : { // Body for login
              'emailOrUsername': email, // Backend uses emailOrUsername for login
              'password': password,
            };

      // Make the HTTP POST request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: const {'Content-Type': 'application/json'}, // Set content type header
        body: json.encode(body), // Encode the body map to a JSON string
      );

      // Decode the JSON response body
      final responseData = json.decode(response.body);

      // Check if the response status code and success flag indicate success
      if (response.statusCode == (_isSignUp ? 201 : 200) && responseData['success'] == true) {
        // Determine the username to pass to the MainMenu
        final String usernameToPass = _isSignUp
            ? username // If signing up, use the entered username
            : responseData['user']['name'] ?? 'User'; // If logging in, get username from the 'user' object in response

        // Navigate to MainMenu on success, replacing the current route
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainMenu(username: usernameToPass), // Pass the username
          ),
        );
      } else {
        // Show an error dialog with the message from the backend response
        _showErrorDialog(context, responseData['message'] ?? 'Operation failed');
      }
    } catch (e) {
      // Catch any exceptions during the HTTP request (network issues, etc.)
      _showErrorDialog(context, 'Connection error: $e');
    } finally {
      // Ensure loading state is set to false after the operation completes or fails
      setState(() => _isLoading = false);
    }
  }

  // --- Forgot Password Logic (Modified to navigate to ResetPassword page) ---
  void _forgotPassword(BuildContext context) {
      // Navigate to the new ResetPassword page
      Navigator.pushNamed(context, '/resetPassword');
  }
  // --- End Forgot Password Logic ---


  // Helper function to show error dialogs
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isSignUp ? 'Sign Up Failed' : 'Login Failed'), // Dynamic title
        content: Text(message), // Display the error message
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), // Button to close the dialog
            child: const Text('OK'),
          )
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // Scaffold background color is handled by MaterialApp theme

      body: Center( // Center the content in the middle of the screen
        child: SingleChildScrollView( // Allows content to be scrollable if it overflows
          padding: const EdgeInsets.all(50), // Padding around the content
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Center items horizontally
            mainAxisAlignment: MainAxisAlignment.center, // Center items vertically if space allows
            children: [
              // App Logo/Image
              Image.asset(
                'assets/images/logo_brin.png', // Your logo asset path
                width: 300, // Set image width
                height: 200, // Set image height
                // color: Colors.white, // Optional: tint the image white if it's grayscale/dark
                // colorBlendMode: BlendMode.modulate, // Optional: blend mode if tinting
              ),
              // Added text below the BRIN image with updated style
              const SizedBox(height: 8), // Space between image and text
              const Text(
                  'Mobile Farm Monitoring',
                   style: TextStyle(
                      fontSize: 26, // You can adjust this size
                      fontWeight: FontWeight.bold, // Make it bold
                      color: Color.fromARGB(221, 255, 255, 255), // Use a dark color visible on white background
                    ),
                    textAlign: TextAlign.center,
              ),
              // Reduced space after the text and before the title
              // Adjusted this SizedBox height to reduce the gap further
              const SizedBox(height: 15), // Reduced from 20

              // Title (Login or Register)
              Text(
                _isSignUp
                    ? 'Register to Mobile Smart Farm Monitoring'
                    : 'Login to Mobile Smart Farm Monitoring',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, // Existing title color
                ),
                  textAlign: TextAlign.center, // Center the text
              ),
              // Reduced space after the title and before the email field
              const SizedBox(height: 20), // Kept this at 20 for spacing before the input fields

              // Email TextField
              TextField(
                controller: _emailController, // Link to the email controller
                keyboardType: TextInputType.emailAddress, // Suggest email keyboard
                decoration: InputDecoration( // Input field styling
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20), // Rounded corners
                  ),
                  focusedBorder: OutlineInputBorder( // Style when the field is focused
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.purple), // Purple border when focused
                  ),
                  // Removed filled and fillColor
                ),
                  // Removed explicit style
              ),
              const SizedBox(height: 16), // Space after email field

              // Username TextField (Shown only during Sign Up)
              if (_isSignUp)
                Column( // Wrap username field in a Column for spacing
                  children: [
                    TextField(
                      controller: _usernameController, // Link to the username controller
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.purple),
                        ),
                        // Removed filled and fillColor
                      ),
                      // Removed explicit style
                    ),
                    const SizedBox(height: 16), // Space after username field
                  ],
                ),

              // Password TextField
              TextField(
                controller: _passwordController, // Link to the password controller
                obscureText: true, // Hide entered text for password
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.purple),
                  ),
                  // Removed filled and fillColor
                ),
                  // Removed explicit style
              ),
              const SizedBox(height: 32), // Space after password field (kept this size for button spacing)

              // Login/Sign Up Button
              ElevatedButton(
                // Disable button while loading
                onPressed: _isLoading ? null : () => _loginOrSignUp(context),
                style: ElevatedButton.styleFrom(
                  // Use primary color from theme, or a specific color
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Rounded button corners
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 15), // Button padding
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white) // Show loader while loading
                    : Text(
                        _isSignUp ? 'Sign Up' : 'Login', // Button text changes based on state
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18), // Keep text white for visibility on button
                    ),
              ),
              const SizedBox(height: 16), // Space after main button

              // --- Forgot Password Button ---
              if (!_isSignUp) // Show Forgot Password only on the Login screen
                  TextButton(
                    onPressed: () => _forgotPassword(context), // Call forgot password function
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.blue), // Use blue color for link
                    ),
                  ),
                const SizedBox(height: 8), // Space after forgot password button (if visible)

              // Toggle Login/Sign Up Button
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp; // Toggle between login and sign up state
                      // Clear fields when toggling?
                      _emailController.clear(); // Clear fields for a cleaner switch
                      _passwordController.clear();
                      _usernameController.clear();
                  });
                },
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Login'
                      : 'Create an account',
                  style: const TextStyle(color: Colors.blue), // Use blue color for link
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
