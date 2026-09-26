import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local, on-device storage for the user's own Gemini API key.
///
/// Setup required (not included in this file):
///   Add to pubspec.yaml:  shared_preferences: ^2.2.0
///
/// Caveat: SharedPreferences stores this in plaintext app storage. That's a
/// reasonable tradeoff for a personal practice app, but if this ever ships
/// to other people, swap this for `flutter_secure_storage` instead, which
/// uses the Keychain/Keystore.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const _prefKey = 'gemini_api_key';

  /// Returns the user's saved key, or an empty string if they haven't set
  /// one yet. CefrScoringService already throws a clear "No Gemini API key
  /// set. Add one in Settings." error when this comes back empty, so the
  /// UI handles it gracefully — no key is baked into the app itself.
  static Future<String> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_prefKey) ?? '').trim();
  }

  /// Whether the user has entered their own key (as opposed to relying on
  /// the built-in default). Handy if a screen wants to show which one is
  /// active.
  static Future<bool> hasCustomApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_prefKey) ?? '').trim().isNotEmpty;
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Deliberately reads the raw stored value here, not
    // SettingsScreen.loadApiKey() — that method fills in the default key
    // for API calls, but this field should stay blank when the user hasn't
    // entered their own key, so they see the "leave blank to use the
    // default" hint instead of the literal placeholder string.
    final prefs = await SharedPreferences.getInstance();
    _controller.text = prefs.getString(SettingsScreen._prefKey) ?? '';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SettingsScreen._prefKey, _controller.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gemini API Key', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Get a free key at aistudio.google.com/apikey. Used only '
                    'for CEFR level scoring — stored locally on this device '
                    'and only sent to Google\'s Gemini API when you tap '
                    '"Get CEFR Level."',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'AIza...',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ),
    );
  }
}