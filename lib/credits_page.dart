import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  // Replace with your actual URLs
  final String patreonUrl = "https://www.patreon.com/yourusername";
  final String kofiUrl = "https://ko-fi.com/yourusername";

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.primary,
      appBar: AppBar(
        title: const Text("Credits"),
        centerTitle: true,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // About Me Section
              CircleAvatar(
                radius: 50,
                backgroundColor: colors.onPrimary.withOpacity(0.1),
                child: Icon(Icons.person, size: 60, color: colors.onPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                "Hello! I'm just a high school student with too much time. "
                "\nThanks for checking this app out and supporting what I do! "
                "\n\nCredit to @benesherick for the idea. ",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Patreon Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.onPrimary,
                  foregroundColor: colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.favorite),
                label: const Text("Support on Patreon"),
                onPressed: () => _launchUrl(patreonUrl),
              ),
              const SizedBox(height: 16),

              // Ko-fi Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.onPrimary,
                  foregroundColor: colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.local_cafe),
                label: const Text("Buy me a Ko-fi"),
                onPressed: () => _launchUrl(kofiUrl),
              ),

              const SizedBox(height: 40),
              Text(
                "Made in Flutter",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
