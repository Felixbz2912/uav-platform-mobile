import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UavApp());
}

class UavApp extends StatelessWidget {
  const UavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xffe23c39), useMaterial3: true),
      home: const UavHome(),
    );
  }
}

class UavHome extends StatefulWidget {
  const UavHome({super.key});

  @override
  State<UavHome> createState() => _UavHomeState();
}

class _UavHomeState extends State<UavHome> with WidgetsBindingObserver {
  static const _defaultBaseUrl = 'https://uav-leipzig.de';
  static const _baseUrlKey = 'uav_base_url';
  static const _trackerTokenKey = 'uav_tracker_token';

  late final WebViewController _web;
  StreamSubscription<Position>? _posSub;
  Timer? _heartbeat;
  String _baseUrl = _defaultBaseUrl;
  String _trackerToken = '';
  String _status = 'Bereit';
  bool _tracking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _status = 'Lade Plattform...'),
        onPageFinished: (_) => setState(() => _status = _tracking ? 'Tracking aktiv' : 'Bereit'),
      ));
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTracking(sendLeave: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_tracking && state == AppLifecycleState.resumed) {
      _sendLastKnownPosition();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    _trackerToken = prefs.getString(_trackerTokenKey) ?? '';
    await _web.loadRequest(Uri.parse('$_baseUrl/app'));
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
    await prefs.setString(_trackerTokenKey, _trackerToken);
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _status = 'Ortungsdienst ist aus');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _status = 'Standort nicht erlaubt');
      return false;
    }
    return true;
  }

  Future<void> _startTracking() async {
    if (_trackerToken.trim().isEmpty) {
      await _openSettings();
      if (_trackerToken.trim().isEmpty) return;
    }
    if (!await _ensureLocationPermission()) return;
    await WakelockPlus.enable();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _sendPosition,
      onError: (_) => setState(() => _status = 'Standortfehler'),
      cancelOnError: false,
    );
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) => _sendLastKnownPosition());
    setState(() {
      _tracking = true;
      _status = 'Tracking aktiv';
    });
    await _sendLastKnownPosition();
  }

  Future<void> _stopTracking({bool sendLeave = false}) async {
    await _posSub?.cancel();
    _posSub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    await WakelockPlus.disable();
    if (sendLeave && _trackerToken.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/tracker/leave'),
          headers: {'Authorization': 'Bearer $_trackerToken'},
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _tracking = false;
        _status = 'Tracking aus';
      });
    }
  }

  Future<void> _sendLastKnownPosition() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );
      await _sendPosition(p);
    } catch (_) {}
  }

  Future<void> _sendPosition(Position p) async {
    if (_trackerToken.isEmpty) return;
    final battery = await Battery().batteryLevel.catchError((_) => -1);
    final body = <String, dynamic>{
      'lat': p.latitude,
      'lng': p.longitude,
      'accuracy': p.accuracy,
      'heading': p.heading.isFinite ? p.heading : null,
      'speed': p.speed.isFinite ? p.speed : null,
      'battery': battery >= 0 ? battery : null,
      'platform': Platform.operatingSystem,
    };
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/tracker/update'),
            headers: {
              'Authorization': 'Bearer $_trackerToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _status = res.statusCode == 200 ? 'Gesendet ${TimeOfDay.now().format(context)}' : 'Sendefehler ${res.statusCode}');
    } catch (_) {
      if (mounted) setState(() => _status = 'Offline - neuer Versuch folgt');
    }
  }

  Future<void> _openSettings() async {
    final server = TextEditingController(text: _baseUrl);
    final token = TextEditingController(text: _trackerToken);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('App koppeln'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: server, decoration: const InputDecoration(labelText: 'Server-URL')),
            TextField(controller: token, decoration: const InputDecoration(labelText: 'Tracker-Token')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true) {
      _baseUrl = server.text.trim().replaceAll(RegExp(r'/+$'), '');
      _trackerToken = token.text.trim();
      await _saveSettings();
      await _web.loadRequest(Uri.parse('$_baseUrl/app'));
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: WebViewWidget(controller: _web)),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        color: Colors.white,
                        tooltip: 'Einstellungen',
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings),
                      ),
                      FilledButton(
                        onPressed: _tracking ? () => _stopTracking(sendLeave: true) : _startTracking,
                        child: Text(_tracking ? 'Stop' : 'Tracking'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
