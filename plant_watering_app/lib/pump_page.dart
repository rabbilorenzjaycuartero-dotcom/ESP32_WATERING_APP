import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'common.dart';

class PumpPage extends StatefulWidget {
  final AppController c;

  const PumpPage({super.key, required this.c});

  @override
  State<PumpPage> createState() => _PumpPageState();
}

class _PumpPageState extends State<PumpPage> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final theme = Theme.of(context);
    final s = c.status ?? offlineStatus;
    final enabled = !c.offline && !c.busy;
    final seconds = (_drag ?? s.maxWaterMs / 1000).clamp(1, 5).toDouble();
    final on = s.pump;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ConnectionBanner(c: c),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: on
                          ? Colors.blue.withValues(alpha: 0.2)
                          : theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.shower,
                        color: on ? Colors.blue : theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pump status', style: theme.textTheme.bodySmall),
                          Text(
                            c.offline ? '--' : (on ? 'ON' : 'OFF'),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (on)
                      Text(
                        'Stops in ${(s.pumpRemainingMs / 1000).ceil()} s',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Text('Soil moisture', style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text(
                      c.offline
                          ? '--'
                          : '${s.moisture}% · ${s.moisture < s.threshold ? 'Dry' : 'OK'}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: !enabled || on ? null : c.waterNow,
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
                        onPressed: !enabled || !on ? null : c.stopPump,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop pump'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  on
                      ? 'Pump is running. Tap Stop pump to end the cycle early.'
                      : 'Stop is unavailable while the pump is OFF.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Watering duration',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${seconds.round()} s',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  min: 1,
                  max: 5,
                  divisions: 4,
                  value: seconds,
                  label: '${seconds.round()} s',
                  onChanged: enabled ? (v) => setState(() => _drag = v) : null,
                  onChangeEnd: (v) {
                    setState(() => _drag = null);
                    c.setDuration(v.round());
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 s', style: theme.textTheme.bodySmall),
                    Text('5 s', style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Used for every watering cycle, manual or automatic.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Automatic watering'),
                subtitle: Text(
                  '${s.auto ? 'Enabled' : 'Disabled'} · Moisture checks every 2 s',
                ),
                value: s.auto,
                onChanged: enabled ? c.setAuto : null,
              ),
              ListTile(
                title: const Text('Water below'),
                subtitle: const Text('Adjust the threshold on Dashboard.'),
                trailing: Text(
                  '${s.threshold}% moisture',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Safety & cooldown',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _row(
                  theme,
                  'Maximum pump runtime',
                  '${s.maxWaterMs ~/ 1000} s',
                ),
                const SizedBox(height: 6),
                _row(
                  theme,
                  'Auto cooldown remaining',
                  '${(s.cooldownRemainingMs / 1000).ceil()} s',
                ),
                const SizedBox(height: 10),
                Text(
                  'Automatic cycles pause for ${s.cooldownMs ~/ 1000} s after watering. '
                  'Every cycle stops at the ${s.maxWaterMs ~/ 1000} s limit.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(ThemeData theme, String label, String value) => Row(
    children: [
      Text(label, style: theme.textTheme.bodyMedium),
      const Spacer(),
      Text(
        value,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    ],
  );
}
