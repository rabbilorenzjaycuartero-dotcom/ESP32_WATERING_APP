import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'dashboard_page.dart';
import 'logs_page.dart';
import 'notifications_page.dart';
import 'pump_page.dart';

void main() => runApp(const PlantWateringApp());

class PlantWateringApp extends StatelessWidget {
  const PlantWateringApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF287A3D);
    return MaterialApp(
      title: 'Plant Watering',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _c = AppController();
  int _tab = 0;

  static const _titles = [
    'Plant Watering',
    'Pump Control',
    'Logs',
    'Notifications',
  ];

  @override
  void initState() {
    super.initState();
    _c.addListener(_showCommandError);
  }

  @override
  void dispose() {
    _c.removeListener(_showCommandError);
    _c.dispose();
    super.dispose();
  }

  void _showCommandError() {
    final msg = _c.lastCommandError;
    if (msg == null || !mounted) return;
    _c.lastCommandError = null;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Command failed: $msg')));
  }

  Future<void> _editHost() async {
    final controller = TextEditingController(text: _c.api.host);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ESP32 address'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: '192.168.4.1'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) _c.setHost(result);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final pages = [
          DashboardPage(c: _c),
          PumpPage(c: _c),
          LogsPage(c: _c),
          NotificationsPage(c: _c),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_tab]),
            actions: [
              IconButton(
                tooltip: _c.api.demo ? 'Exit demo mode' : 'Demo mode',
                icon: Icon(
                  _c.api.demo ? Icons.science : Icons.science_outlined,
                ),
                onPressed: () => _c.setDemo(!_c.api.demo),
              ),
              IconButton(
                tooltip: 'ESP32 address',
                icon: const Icon(Icons.settings_ethernet),
                onPressed: _editHost,
              ),
            ],
          ),
          body: IndexedStack(index: _tab, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.shower_outlined),
                selectedIcon: Icon(Icons.shower),
                label: 'Pump',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history),
                label: 'Logs',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: 'Notifications',
              ),
            ],
          ),
        );
      },
    );
  }
}
