import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'common.dart';

class LogsPage extends StatefulWidget {
  final AppController c;

  const LogsPage({super.key, required this.c});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  EventType? _filter; // null = All

  static const _filters = <(String, EventType?)>[
    ('All', null),
    ('Moisture', EventType.moisture),
    ('Watering', EventType.watering),
    ('System', EventType.system),
  ];

  IconData _icon(EventType t) => switch (t) {
    EventType.moisture => Icons.water_drop_outlined,
    EventType.watering => Icons.shower,
    EventType.system => Icons.settings_outlined,
  };

  String _label(EventType t) => switch (t) {
    EventType.moisture => 'Moisture',
    EventType.watering => 'Watering',
    EventType.system => 'System',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.c;
    final shown = c.events
        .where((e) => _filter == null || e.type == _filter)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ConnectionBanner(c: c),
        const SizedBox(height: 12),
        StatusSummary(c: c),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16),
            const SizedBox(width: 6),
            Text(
              'Today, ${shortDate(DateTime.now())}',
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            Text('Newest first', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final (name, type) in _filters)
              ChoiceChip(
                label: Text(name),
                selected: _filter == type,
                onSelected: (_) => setState(() => _filter = type),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              c.api.demo ? 'Demo activity' : 'Activity',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            Text('${shown.length} events', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: shown.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No events yet')),
                )
              : Column(
                  children: [
                    for (final e in shown)
                      ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          child: Icon(_icon(e.type), size: 18),
                        ),
                        title: Text(e.title, style: theme.textTheme.bodyMedium),
                        subtitle: Text(
                          '${clock(e.time)}${e.detail.isEmpty ? '' : ' · ${e.detail}'}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Text(
                          _label(e.type),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Events are kept for this session only.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
