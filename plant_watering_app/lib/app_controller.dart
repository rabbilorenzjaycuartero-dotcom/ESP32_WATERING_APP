import 'dart:async';

import 'package:flutter/foundation.dart';

import 'esp32_api.dart';

enum EventType { moisture, watering, system }

class LogEvent {
  final DateTime time;
  final EventType type;
  final String title;
  final String detail;

  const LogEvent(this.time, this.type, this.title, this.detail);
}

enum AlertKind { lowMoisture, pumpRuntime, info }

class AppAlert {
  final DateTime time;
  final AlertKind kind;
  final String title;
  final String detail;
  String state; // Active, Resolved, Complete, System

  AppAlert(this.time, this.kind, this.title, this.detail, this.state);
}

/// Owns the ESP32 connection, polling, and the in-app event/alert history.
class AppController extends ChangeNotifier {
  static const pollInterval = Duration(seconds: 2);
  static const historyLength = 60;
  static const _maxEvents = 200;

  final Esp32Api api = Esp32Api();
  final List<int> history = [];
  final List<LogEvent> events = [];
  final List<AppAlert> alerts = [];

  bool alertLowMoisture = true;
  bool alertPumpRuntime = true;

  PlantStatus? status;
  String? error;
  bool busy = false;

  Timer? _timer;
  PlantStatus? _prev;
  DateTime? _pumpStartedAt;
  bool _manualRequest = false;
  AppAlert? _activeLowAlert;
  bool _disposed = false;

  AppController() {
    refresh();
    _timer = Timer.periodic(pollInterval, (_) => refresh());
  }

  bool get offline => status == null || error != null;

  Future<void> refresh() => _run(api.status, silent: true);

  Future<void> waterNow() {
    _manualRequest = true;
    return _run(api.pumpOn);
  }

  Future<void> stopPump() => _run(api.pumpOff);

  Future<void> setAuto(bool enabled) => _run(() => api.setAuto(enabled));

  Future<void> setThreshold(int percent) =>
      _run(() => api.setSettings(threshold: percent));

  Future<void> setDuration(int seconds) =>
      _run(() => api.setSettings(durationMs: seconds * 1000));

  void setHost(String host) {
    api.host = host;
    _reset('ESP32 address set to $host');
    refresh();
  }

  void setDemo(bool enabled) {
    api.demo = enabled;
    _reset(enabled ? 'Demo mode on' : 'Demo mode off');
    refresh();
  }

  void _reset(String why) {
    history.clear();
    status = null;
    error = null;
    _prev = null;
    _pumpStartedAt = null;
    _activeLowAlert = null;
    _log(EventType.system, why, '');
    notifyListeners();
  }

  Future<void> _run(
    Future<PlantStatus> Function() action, {
    bool silent = false,
  }) async {
    if (!silent) {
      busy = true;
      notifyListeners();
    }
    try {
      final next = await action();
      if (_disposed) return;
      error = null;
      status = next;
      history.add(next.moisture);
      if (history.length > historyLength) history.removeAt(0);
      _record(_prev, next);
      _prev = next;
    } catch (e) {
      if (_disposed) return;
      error = 'Cannot reach ESP32 at ${api.host}';
      lastCommandError = silent ? null : '$e';
    } finally {
      if (!_disposed) {
        if (!silent) busy = false;
        notifyListeners();
      }
    }
  }

  /// Set when a user-triggered command fails; the UI shows it once and clears it.
  String? lastCommandError;

  void _record(PlantStatus? prev, PlantStatus next) {
    final now = DateTime.now();
    final dry = next.moisture < next.threshold;

    if (prev == null) {
      _log(
        EventType.system,
        api.demo ? 'Demo session started' : 'Connected to ESP32',
        api.demo ? 'Simulated ESP32 · No hardware connected' : api.host,
      );
      _log(
        EventType.moisture,
        _moistureTitle(next),
        'Raw reading: ${next.raw}',
      );
      if (dry) _openLowAlert(now, next);
      return;
    }

    if (prev.auto != next.auto) {
      _log(
        EventType.system,
        next.auto
            ? 'Automatic watering enabled'
            : 'Automatic watering disabled',
        'Threshold ${next.threshold}%',
      );
    }
    if (prev.threshold != next.threshold) {
      _log(EventType.system, 'Threshold set to ${next.threshold}%', '');
    }
    if (prev.maxWaterMs != next.maxWaterMs) {
      _log(
        EventType.system,
        'Watering duration set to ${next.maxWaterMs ~/ 1000} s',
        '',
      );
    }

    final wasDry = prev.moisture < prev.threshold;
    if (wasDry != dry) {
      _log(
        EventType.moisture,
        _moistureTitle(next),
        dry
            ? 'Below the ${next.threshold}% watering threshold'
            : 'Above the ${next.threshold}% watering threshold',
      );
      if (dry) {
        _openLowAlert(now, next);
      } else {
        _activeLowAlert?.state = 'Resolved';
        _activeLowAlert = null;
      }
    }

    if (!prev.pump && next.pump) {
      _pumpStartedAt = now;
      _log(
        EventType.watering,
        _manualRequest
            ? 'Manual watering started'
            : 'Automatic watering started',
        _manualRequest
            ? 'Pump ON'
            : 'Pump ON · Moisture below ${next.threshold}%',
      );
      _manualRequest = false;
    } else if (prev.pump && !next.pump) {
      final started = _pumpStartedAt;
      final ran = started == null ? null : now.difference(started);
      _pumpStartedAt = null;
      final secs = ran == null
          ? ''
          : '${(ran.inMilliseconds / 1000).round()} s cycle · ';
      _log(
        EventType.watering,
        'Watering completed',
        'Pump OFF · $secs Cooldown ${next.cooldownMs ~/ 1000} s'.replaceAll(
          '  ',
          ' ',
        ),
      );
      if (alertPumpRuntime &&
          ran != null &&
          ran.inMilliseconds >= next.maxWaterMs - 1500) {
        _addAlert(
          AppAlert(
            now,
            AlertKind.pumpRuntime,
            'Pump reached runtime limit',
            'Cycle stopped at the ${next.maxWaterMs ~/ 1000} s limit',
            'Complete',
          ),
        );
      }
    }
  }

  String _moistureTitle(PlantStatus s) =>
      'Soil moisture: ${s.moisture}% · ${s.moisture < s.threshold ? 'Low' : 'OK'}';

  void _openLowAlert(DateTime now, PlantStatus s) {
    if (!alertLowMoisture) return;
    final a = AppAlert(
      now,
      AlertKind.lowMoisture,
      'Low soil moisture',
      '${s.moisture}% was below ${s.threshold}%',
      'Active',
    );
    _activeLowAlert = a;
    _addAlert(a);
  }

  void _addAlert(AppAlert a) {
    alerts.insert(0, a);
    if (alerts.length > 50) alerts.removeLast();
  }

  void _log(EventType type, String title, String detail) {
    events.insert(0, LogEvent(DateTime.now(), type, title, detail));
    if (events.length > _maxEvents) events.removeLast();
  }

  void setAlertLowMoisture(bool v) {
    alertLowMoisture = v;
    notifyListeners();
  }

  void setAlertPumpRuntime(bool v) {
    alertPumpRuntime = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    api.close();
    super.dispose();
  }
}
