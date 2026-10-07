import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'esp32_api.dart';

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
  static const _pollInterval = Duration(seconds: 2);
  static const _historyLength = 60;

  final _api = Esp32Api();
  final List<int> _history = [];
  Timer? _timer;
  PlantStatus? _status;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.close();
    super.dispose();
  }

  Future<void> _refresh() => _run(_api.status, silent: true);

  Future<void> _run(Future<PlantStatus> Function() action,
      {bool silent = false}) async {
    if (!silent) setState(() => _busy = true);
    try {
      final status = await action();
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
        _history.add(status.moisture);
        if (_history.length > _historyLength) _history.removeAt(0);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Cannot reach ESP32 at ${_api.host}');
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Command failed: $e')),
        );
      }
    } finally {
      if (mounted && !silent) setState(() => _busy = false);
    }
  }

  Future<void> _editHost() async {
    final controller = TextEditingController(text: _api.host);
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
    if (result != null && result.isNotEmpty) {
      setState(() {
        _api.host = result;
        _history.clear();
        _status = null;
      });
      _refresh();
    }
  }

  void _setDemo(bool enabled) {
    setState(() {
      _api.demo = enabled;
      _history.clear();
      _status = null;
      _error = null;
    });
    _refresh();
  }

  static const _offlineStatus = PlantStatus(
    moisture: 0,
    raw: 0,
    pump: false,
    auto: true,
    threshold: 35,
    pumpRemainingMs: 0,
    cooldownRemainingMs: 0,
  );

  @override
  Widget build(BuildContext context) {
    // While the ESP32 is unreachable, show the dashboard with controls disabled.
    final offline = _status == null || _error != null;
    final status = _status ?? _offlineStatus;
    final controlsEnabled = !offline && !_busy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Watering'),
        actions: [
          IconButton(
            tooltip: _api.demo ? 'Exit demo mode' : 'Demo mode',
            icon: Icon(_api.demo ? Icons.science : Icons.science_outlined),
            onPressed: () => _setDemo(!_api.demo),
          ),
          IconButton(
            tooltip: 'ESP32 address',
            icon: const Icon(Icons.settings_ethernet),
            onPressed: _editHost,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ConnectionBanner(
              error: _error,
              connected: _status != null,
              demo: _api.demo,
              onDemo: () => _setDemo(true),
            ),
            const SizedBox(height: 12),
            _MoistureCard(status: status, offline: offline),
            const SizedBox(height: 12),
            _PumpCard(
              status: status,
              enabled: controlsEnabled,
              offline: offline,
              onWater: () => _run(_api.pumpOn),
              onStop: () => _run(_api.pumpOff),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.autorenew),
                title: const Text('Automatic watering'),
                subtitle: Text(
                    'Waters when moisture drops below ${status.threshold}%'),
                value: status.auto,
                onChanged:
                    controlsEnabled ? (v) => _run(() => _api.setAuto(v)) : null,
              ),
            ),
            const SizedBox(height: 12),
            _HistoryCard(history: _history, threshold: status.threshold),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final String? error;
  final bool connected;
  final bool demo;
  final VoidCallback onDemo;

  const _ConnectionBanner({
    required this.error,
    required this.connected,
    required this.demo,
    required this.onDemo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = error == null && connected;
    final fg = ok ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? scheme.primaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
              demo
                  ? Icons.science
                  : (ok ? Icons.wifi : Icons.wifi_off),
              color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              demo
                  ? 'Demo mode: simulated ESP32'
                  : ok
                      ? 'Connected to Plant-Watering'
                      : (error ??
                          'Connecting… Join the "Plant-Watering" Wi-Fi first'),
              style: TextStyle(color: fg),
            ),
          ),
          if (!ok && !demo)
            TextButton(onPressed: onDemo, child: const Text('Try demo')),
        ],
      ),
    );
  }
}

class _MoistureCard extends StatelessWidget {
  final PlantStatus status;
  final bool offline;

  const _MoistureCard({required this.status, required this.offline});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dry = status.moisture < status.threshold;
    final color = offline
        ? theme.colorScheme.outline
        : (dry ? Colors.orange : theme.colorScheme.primary);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Soil moisture', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: status.moisture / 100),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 14,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(dry ? Icons.water_drop_outlined : Icons.water_drop,
                            color: color, size: 28),
                        Text(offline ? '--' : '${status.moisture}%',
                            style: theme.textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(offline ? 'Offline' : (dry ? 'Dry' : 'OK'),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: color)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Raw reading: ${offline ? '--' : status.raw}',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PumpCard extends StatelessWidget {
  final PlantStatus status;
  final bool enabled;
  final bool offline;
  final VoidCallback onWater;
  final VoidCallback onStop;

  const _PumpCard({
    required this.status,
    required this.enabled,
    required this.offline,
    required this.onWater,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String detail;
    if (offline) {
      detail = 'No connection';
    } else if (status.pump) {
      detail = 'Stops in ${(status.pumpRemainingMs / 1000).ceil()} s';
    } else if (status.cooldownRemainingMs > 0 && status.auto) {
      detail =
          'Auto cooldown: ${(status.cooldownRemainingMs / 1000).ceil()} s';
    } else {
      detail = 'Idle';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shower,
                    color: status.pump
                        ? Colors.blue
                        : theme.colorScheme.outline),
                const SizedBox(width: 10),
                Text('Pump: ${status.pump ? 'ON' : 'OFF'}',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !enabled || status.pump ? null : onWater,
                    icon: const Icon(Icons.water_drop),
                    label: const Text('Water now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    onPressed: !enabled || !status.pump ? null : onStop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop pump'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final List<int> history;
  final int threshold;

  const _HistoryCard({required this.history, required this.threshold});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 2 minutes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _HistoryPainter(
                  history: history,
                  threshold: threshold,
                  lineColor: theme.colorScheme.primary,
                  thresholdColor: Colors.orange,
                  gridColor: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  final List<int> history;
  final int threshold;
  final Color lineColor;
  final Color thresholdColor;
  final Color gridColor;

  _HistoryPainter({
    required this.history,
    required this.threshold,
    required this.lineColor,
    required this.thresholdColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double yFor(num percent) => size.height * (1 - percent / 100);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final p in [0, 50, 100]) {
      canvas.drawLine(Offset(0, yFor(p)), Offset(size.width, yFor(p)), grid);
    }

    final thresholdPaint = Paint()
      ..color = thresholdColor
      ..strokeWidth = 1.5;
    final ty = yFor(threshold);
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(
          Offset(x, ty), Offset(math.min(x + 4, size.width), ty), thresholdPaint);
    }

    if (history.length < 2) return;
    final step = size.width / (_HomePageState._historyLength - 1);
    final startX = size.width - step * (history.length - 1);
    final path = Path();
    for (var i = 0; i < history.length; i++) {
      final pt = Offset(startX + step * i, yFor(history[i]));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(startX, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = lineColor.withValues(alpha: 0.12));
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter old) => true;
}
