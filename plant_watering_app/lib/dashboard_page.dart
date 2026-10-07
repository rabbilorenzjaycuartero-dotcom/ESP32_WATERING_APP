import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'common.dart';
import 'esp32_api.dart';

class DashboardPage extends StatelessWidget {
  final AppController c;
  const DashboardPage({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final status = c.status ?? offlineStatus;
    final enabled = !c.offline && !c.busy;
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConnectionBanner(c: c),
          const SizedBox(height: 12),
          _MoistureCard(status: status, offline: c.offline),
          const SizedBox(height: 12),
          _PumpCard(
            status: status,
            enabled: enabled,
            offline: c.offline,
            onWater: c.waterNow,
            onStop: c.stopPump,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.autorenew),
                  title: const Text('Automatic watering'),
                  subtitle: Text(
                    'Waters when moisture drops below the selected threshold',
                  ),
                  value: status.auto,
                  onChanged: enabled ? c.setAuto : null,
                ),
                ThresholdSlider(c: c, status: status),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HistoryCard(history: c.history, threshold: status.threshold),
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
                        Icon(
                          dry ? Icons.water_drop_outlined : Icons.water_drop,
                          color: color,
                          size: 28,
                        ),
                        Text(
                          offline ? '--' : '${status.moisture}%',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          offline ? 'Offline' : (dry ? 'Dry' : 'OK'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Raw reading: ${offline ? '--' : status.raw}',
              style: theme.textTheme.bodySmall,
            ),
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
      detail = 'Auto cooldown: ${(status.cooldownRemainingMs / 1000).ceil()} s';
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
                Icon(
                  Icons.shower,
                  color: status.pump ? Colors.blue : theme.colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Text(
                  'Pump: ${status.pump ? 'ON' : 'OFF'}',
                  style: theme.textTheme.titleMedium,
                ),
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
        Offset(x, ty),
        Offset(math.min(x + 4, size.width), ty),
        thresholdPaint,
      );
    }

    if (history.length < 2) return;
    final step = size.width / (AppController.historyLength - 1);
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
