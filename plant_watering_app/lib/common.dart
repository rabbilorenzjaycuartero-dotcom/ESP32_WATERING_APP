import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'esp32_api.dart';

const offlineStatus = PlantStatus(
  moisture: 0,
  raw: 0,
  pump: false,
  auto: true,
  threshold: 35,
  pumpRemainingMs: 0,
  cooldownRemainingMs: 0,
);

class ConnectionBanner extends StatelessWidget {
  final AppController c;

  const ConnectionBanner({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final demo = c.api.demo;
    final ok = !c.offline;
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
            demo ? Icons.science : (ok ? Icons.wifi : Icons.wifi_off),
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              demo
                  ? 'Demo mode: simulated ESP32'
                  : ok
                  ? 'Connected to Plant-Watering'
                  : (c.error ??
                        'Connecting… Join the "Plant-Watering" Wi-Fi first'),
              style: TextStyle(color: fg),
            ),
          ),
          if (!ok && !demo)
            TextButton(
              onPressed: () => c.setDemo(true),
              child: const Text('Try demo'),
            ),
        ],
      ),
    );
  }
}

/// Compact "63% moisture · OK / Pump: OFF" card shown on the secondary tabs.
class StatusSummary extends StatelessWidget {
  final AppController c;

  const StatusSummary({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = c.status;
    final offline = c.offline || s == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offline
                        ? 'Offline'
                        : '${s.moisture}% moisture · ${s.moisture < s.threshold ? 'Dry' : 'OK'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    offline
                        ? 'No connection'
                        : 'Automatic watering ${s.auto ? 'ON' : 'OFF'} · Threshold ${s.threshold}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              offline ? '' : 'Pump: ${s.pump ? 'ON' : 'OFF'}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Threshold slider that only sends the value to the ESP32 when released.
class ThresholdSlider extends StatefulWidget {
  final AppController c;
  final PlantStatus status;

  const ThresholdSlider({super.key, required this.c, required this.status});

  @override
  State<ThresholdSlider> createState() => _ThresholdSliderState();
}

class _ThresholdSliderState extends State<ThresholdSlider> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = !widget.c.offline && !widget.c.busy;
    final value = (_drag ?? widget.status.threshold.toDouble()).clamp(5, 95);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text('Threshold', style: theme.textTheme.bodyMedium),
          Expanded(
            child: Slider(
              min: 5,
              max: 95,
              divisions: 90,
              value: value.toDouble(),
              label: '${value.round()}%',
              onChanged: enabled ? (v) => setState(() => _drag = v) : null,
              onChangeEnd: (v) {
                setState(() => _drag = null);
                widget.c.setThreshold(v.round());
              },
            ),
          ),
          Chip(
            label: Text('${value.round()}%'),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

String two(int n) => n.toString().padLeft(2, '0');

String clock(DateTime t) => '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String shortDate(DateTime t) => '${t.day} ${_months[t.month - 1]}';
