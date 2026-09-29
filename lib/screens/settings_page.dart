import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onLogout;
  final bool isDark;
  final Future<void> Function(bool value) onThemeChanged;

  const SettingsPage({
    super.key,
    required this.onLogout,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (!value) {
      await NotificationService.instance.cancelAll();
    }
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Notifikasi & alarm diaktifkan.'
              : 'Semua notifikasi & alarm dinonaktifkan.',
        ),
      ),
    );
  }

  Future<void> _testAlarm() async {
    await NotificationService.instance.showTestNotification(delaySeconds: 5);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏱️ Alarm tes dijadwalkan dalam 5 detik... Silakan kunci / tunggu HP Anda.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF1FA8FF),
              ),
              title: const Text('Notifications'),
              subtitle: const Text('Manage schedule reminders'),
              trailing: Switch(
                value: _notificationsEnabled,
                activeThumbColor: const Color(0xFF1FA8FF),
                onChanged: _toggleNotifications,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.alarm_on_rounded,
                color: Color(0xFF1FA8FF),
              ),
              title: const Text('Tes Alarm (5 Detik)'),
              subtitle: const Text('Uji coba apakah notifikasi alarm berbunyi'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: _testAlarm,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.dark_mode_outlined,
                color: Color(0xFF1FA8FF),
              ),
              title: const Text('Dark Mode'),
              subtitle: const Text('Change application theme'),
              trailing: Switch(
                value: widget.isDark,
                activeThumbColor: const Color(0xFF1FA8FF),
                onChanged: widget.onThemeChanged,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.dns_outlined,
                color: Color(0xFF1FA8FF),
              ),
              title: const Text('Server API URL'),
              subtitle: FutureBuilder<String>(
                future: AuthService.getApiBaseUrl(),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? AuthService.defaultApiBaseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () async {
                final currentUrl = await AuthService.getApiBaseUrl();
                if (!mounted) return;
                final controller = TextEditingController(text: currentUrl);

                final newUrl = await showDialog<String>(
                  context: mounted ? context : context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Server API URL'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Masukkan URL server backend Anda (contoh: http://192.168.1.10:3000/api untuk HP fisik):',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'http://192.168.x.x:3000/api',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          controller.text = AuthService.defaultApiBaseUrl;
                        },
                        child: const Text('Reset Default'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, controller.text),
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                );

                if (newUrl != null) {
                  await AuthService.setCustomApiUrl(newUrl);
                  if (mounted) setState(() {});
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.logout_outlined,
                color: Color(0xFF1FA8FF),
              ),
              title: const Text('Logout'),
              subtitle: const Text('Keluar dari akun saat ini'),
              onTap: () async {
                await AuthService.logout();
                widget.onLogout();
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF1FA8FF)),
              title: const Text('About'),
              subtitle: const Text('MySchedule'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'MySchedule',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'Flutter Application',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
