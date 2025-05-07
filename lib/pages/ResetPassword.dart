import 'package:flutter/material.dart';

// A page for users to reset their password.
// Class name changed to ResetPassword as requested.
class ResetPassword extends StatefulWidget {
  const ResetPassword({Key? key}) : super(key: key);

  @override
  // The state class name also needs to match the widget class name convention.
  _ResetPasswordState createState() => _ResetPasswordState();
}

// State class for the ResetPassword widget.
class _ResetPasswordState extends State<ResetPassword> {
  // Controllers for the text input fields.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Global key for the form to allow validation.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // State variable to show/hide password.
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed.
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Placeholder function for the password reset logic.
  // You will need to replace this with your actual backend API call.
  Future<void> _resetPassword() async {
    // Validate the form fields.
    if (_formKey.currentState?.validate() ?? false) {
      // If validation passes, proceed with reset logic.
      final email = _emailController.text;
      final newPassword = _newPasswordController.text;
      final confirmPassword = _confirmPasswordController.text;

      // Basic check that passwords match (already done in validator, but good practice).
      if (newPassword != confirmPassword) {
        // This case should ideally be caught by the validator, but included for safety.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')),
        );
        return;
      }

      // --- REPLACE WITH YOUR BACKEND API CALL ---
      print('Attempting to reset password for email: $email');
      print('New password: $newPassword'); // Be cautious about logging passwords in real apps!

      // Simulate a network request delay.
      await Future.delayed(const Duration(seconds: 2));

      // --- Example of a successful reset ---
      // if (resetWasSuccessful) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Password reset successfully!')),
      //   );
      //   // Navigate back to the login page after successful reset.
      //   Navigator.pop(context);
      // } else {
      //   // Example of a failed reset.
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Failed to reset password. Please try again.')),
      //   );
      // }
      // --- END OF REPLACEABLE SECTION ---

      // For now, just show a success message and navigate back.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset attempt initiated. (Replace with backend call)')),
      );
       // Navigate back to the login page after attempting reset.
       // Consider if you only want to pop on actual success.
       Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        centerTitle: true,
      ),
      body: Center( // Center the content vertically and horizontally
        child: SingleChildScrollView( // Allows the page to scroll if content overflows
          padding: const EdgeInsets.all(24.0), // Padding around the content
          child: Form(
            key: _formKey, // Assign the form key
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center column content vertically
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch column children horizontally
              children: <Widget>[
                // Email Input Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    // Basic email format validation
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                       return 'Please enter a valid email address';
                    }
                    return null; // Return null if the input is valid
                  },
                ),
                const SizedBox(height: 16.0), // Spacing

                // New Password Input Field
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_isNewPasswordVisible, // Hide/show password
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                     suffixIcon: IconButton(
                       icon: Icon(
                         _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                         color: Theme.of(context).primaryColorDark,
                       ),
                       onPressed: () {
                         setState(() {
                           _isNewPasswordVisible = !_isNewPasswordVisible;
                         });
                       },
                     ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new password';
                    }
                    if (value.length < 6) { // Example: minimum 6 characters
                       return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0), // Spacing

                // Confirm New Password Input Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible, // Hide/show password
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                     suffixIcon: IconButton(
                       icon: Icon(
                         _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                         color: Theme.of(context).primaryColorDark,
                       ),
                       onPressed: () {
                         setState(() {
                           _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                         });
                       },
                     ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24.0), // Spacing before button

                // Reset Password Button
                ElevatedButton(
                  onPressed: _resetPassword, // Call the reset password function
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text('Reset Password', style: TextStyle(fontSize: 16)),
                ),
                 const SizedBox(height: 16.0), // Spacing

                 // Back to Login Link/Button
                 TextButton(
                    onPressed: () {
                       Navigator.pop(context); // Navigate back to the previous page (Login)
                    },
                    child: const Text('Back to Login'),
                 ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
