import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

class PlantStatus {
  final int moisture;
  final int raw;
  final bool pump;
  final bool auto;
  final int threshold;
  final int maxWaterMs;
  final int cooldownMs;
  final int pumpRemainingMs;
  final int cooldownRemainingMs;

  const PlantStatus({
    required this.moisture,
    required this.raw,
    required this.pump,
    required this.auto,
    required this.threshold,
    this.maxWaterMs = 5000,
    this.cooldownMs = 60000,
    required this.pumpRemainingMs,
    required this.cooldownRemainingMs,
  });

  factory PlantStatus.fromJson(Map<String, dynamic> json) => PlantStatus(
    moisture: (json['moisture'] as num).toInt(),
    raw: (json['raw'] as num).toInt(),
    pump: json['pump'] as bool,
    auto: json['auto'] as bool,
    threshold: (json['threshold'] as num?)?.toInt() ?? 35,
    maxWaterMs: (json['maxWaterMs'] as num?)?.toInt() ?? 5000,
    cooldownMs: (json['cooldownMs'] as num?)?.toInt() ?? 60000,
    pumpRemainingMs: (json['pumpRemainingMs'] as num?)?.toInt() ?? 0,
    cooldownRemainingMs: (json['cooldownRemainingMs'] as num?)?.toInt() ?? 0,
  );
}

class Esp32Api {
  String host;
  bool demo = false;
  final _sim = _SimulatedEsp32();
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);

  Esp32Api({this.host = '192.168.4.1'});

  Future<PlantStatus> status() => _request('GET', '/api/status');
  Future<PlantStatus> pumpOn() => _request('POST', '/api/pump/on');
  Future<PlantStatus> pumpOff() => _request('POST', '/api/pump/off');
  Future<PlantStatus> setAuto(bool enabled) =>
      _request('POST', '/api/auto?enabled=${enabled ? 1 : 0}');
  Future<PlantStatus> setSettings({int? threshold, int? durationMs}) {
    final query = [
      if (threshold != null) 'threshold=$threshold',
      if (durationMs != null) 'duration=$durationMs',
    ].join('&');
    return _request('POST', '/api/settings?$query');
  }

  Future<PlantStatus> _request(String method, String path) async {
    if (demo) return _sim.handle(path);
    final uri = Uri.parse('http://$host$path');
    final req = await _client.openUrl(method, uri);
    if (method == 'POST') req.contentLength = 0;
    final res = await req.close().timeout(const Duration(seconds: 4));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: uri);
    }
    return PlantStatus.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  void close() => _client.close(force: true);
}

/// Mimics the ESP32 firmware so the app can be tried without the hardware.
class _SimulatedEsp32 {
  int _threshold = 35;
  Duration _maxWater = const Duration(seconds: 5);
  static const _cooldown = Duration(seconds: 60);

  double _moisture = 45;
  bool _pump = false;
  bool _auto = true;
  DateTime _pumpStartedAt = DateTime.now();
  DateTime? _lastWaterFinishedAt;
  DateTime _lastTick = DateTime.now();

  PlantStatus handle(String path) {
    _tick();
    if (path == '/api/pump/on') _startPump();
    if (path == '/api/pump/off') _stopPump();
    if (path.startsWith('/api/auto')) _auto = path.endsWith('enabled=1');
    if (path.startsWith('/api/settings')) {
      final q = Uri.parse(path).queryParameters;
      final t = int.tryParse(q['threshold'] ?? '');
      final d = int.tryParse(q['duration'] ?? '');
      if (t != null) _threshold = t.clamp(5, 95);
      if (d != null) _maxWater = Duration(milliseconds: d.clamp(1000, 5000));
    }
    return _snapshot();
  }

  void _tick() {
    final now = DateTime.now();
    final seconds = now.difference(_lastTick).inMilliseconds / 1000;
    _lastTick = now;
    _moisture += _pump ? seconds * 4 : -seconds * 0.5;
    _moisture = _moisture.clamp(0, 100);
    if (_pump && now.difference(_pumpStartedAt) >= _maxWater) _stopPump();
    final cooledDown =
        _lastWaterFinishedAt == null ||
        now.difference(_lastWaterFinishedAt!) >= _cooldown;
    if (_auto && !_pump && cooledDown && _moisture < _threshold) _startPump();
  }

  void _startPump() {
    if (_pump) return;
    _pump = true;
    _pumpStartedAt = DateTime.now();
  }

  void _stopPump() {
    _pump = false;
    _lastWaterFinishedAt = DateTime.now();
  }

  PlantStatus _snapshot() {
    final now = DateTime.now();
    final pumpLeft = _pump ? _maxWater - now.difference(_pumpStartedAt) : null;
    final coolLeft = !_pump && _lastWaterFinishedAt != null
        ? _cooldown - now.difference(_lastWaterFinishedAt!)
        : null;
    final m = _moisture.round();
    return PlantStatus(
      moisture: m,
      raw: 3000 - (m * 17), // same DRY=3000 / WET=1300 mapping as firmware
      pump: _pump,
      auto: _auto,
      threshold: _threshold,
      maxWaterMs: _maxWater.inMilliseconds,
      cooldownMs: _cooldown.inMilliseconds,
      pumpRemainingMs: math.max(0, pumpLeft?.inMilliseconds ?? 0),
      cooldownRemainingMs: math.max(0, coolLeft?.inMilliseconds ?? 0),
    );
  }
}
