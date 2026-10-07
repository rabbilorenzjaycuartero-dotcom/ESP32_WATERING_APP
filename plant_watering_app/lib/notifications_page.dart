import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'common.dart';

class NotificationsPage extends StatelessWidget {
  final AppController c;

  const NotificationsPage({super.key, required this.c});

  IconData _icon(AlertKind k) => switch (k) {
    AlertKind.lowMoisture => Icons.water_drop_outlined,
    AlertKind.pumpRuntime => Icons.timer_outlined,
    AlertKind.info => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ConnectionBanner(c: c),
        const SizedBox(height: 12),
        StatusSummary(c: c),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Recent alerts', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              'Today, ${shortDate(DateTime.now())}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: c.alerts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No alerts')),
                )
              : Column(
                  children: [
                    for (final a in c.alerts)
                      ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          child: Icon(_icon(a.kind), size: 18),
                        ),
                        title: Text(a.title, style: theme.textTheme.bodyMedium),
                        subtitle: Text(
                          '${a.detail}\n${clock(a.time)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          a.state,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: a.state == 'Active'
                                ? Colors.orange
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Text('Notification preferences', style: theme.textTheme.titleMedium),
        Text(
          'Choose which alerts appear in the app.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Low moisture'),
                subtitle: const Text('When moisture drops below the threshold'),
                value: c.alertLowMoisture,
                onChanged: c.setAlertLowMoisture,
              ),
              SwitchListTile(
                title: const Text('Excessive pump runtime'),
                subtitle: const Text(
                  'If a cycle reaches the pump runtime limit',
                ),
                value: c.alertPumpRuntime,
                onChanged: c.setAlertPumpRuntime,
              ),
              const SwitchListTile(
                title: Text('Low tank level'),
                subtitle: Text('Unavailable: no tank sensor in this build'),
                value: false,
                onChanged: null,
              ),
              const SwitchListTile(
                title: Text('Telegram alerts'),
                subtitle: Text('Not connected'),
                value: false,
                onChanged: null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Alerts show inside the app only. No push notifications or '
                'Telegram messages are sent, and they reset when the app closes.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
