import 'package:flutter/material.dart';

class BannergressSignInBanner extends StatelessWidget {
  const BannergressSignInBanner({
    super.key,
    required this.authError,
    required this.onSignIn,
  });

  final String? authError;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final hasError = authError != null;
    final color = hasError ? Colors.red : Colors.blue;

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              hasError ? Icons.error_outline : Icons.account_circle_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasError
                    ? authError!
                    : 'Sign in to sync your To-do list from Bannergress',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onSignIn,
              child: Text('Sign in',
                  style: TextStyle(fontSize: 12, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
