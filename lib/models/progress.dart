import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api.dart';
import '../data/exercises.dart';

class ProgressStore extends ChangeNotifier {
  ProgressStore(this.prefs, {this.api}) {
    _load();
    api?.onUnauthorized = _clearSession;
  }
  final SharedPreferences prefs;
  final CodeBugApi? api;
  bool authenticated = false;
  String? userId;
  String email = '';
  List<({String name, int xp, bool you})> ranking = [];
  Set<String> solved = {}, read = {}, hinted = {}, favorites = {};
  final Set<String> savingFavorites = {};
  Map<String, int> activity = {};
  int attempts = 0, correct = 0, _serverXp = 0;
  int lastAward = 0;
  String name = 'Разработчик', language = 'Все';
  String? active;
  bool dark = true, largeCode = false, saveFailed = false;
  String? syncError;
  Map<String, dynamic>? _unsyncedProfile;
  Future<void> _pending = Future.value();
  static String dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  DateTime get _today => api == null ? DateTime.now() : DateTime.now().toUtc();
  void _load() {
    dark = prefs.getBool('dark') ?? true;
    largeCode = prefs.getBool('largeCode') ?? false;
    if (api != null) return;
    try {
      final raw = prefs.getString('progress_v1');
      if (raw != null) _apply(jsonDecode(raw));
    } catch (_) {
      saveFailed = true;
    }
  }

  void _apply(Map<String, dynamic> data) {
    favorites = Set<String>.from(data['favorites'] ?? []);
    solved = Set<String>.from(data['solved'] ?? []);
    read = Set<String>.from(data['read'] ?? []);
    hinted = Set<String>.from(data['hinted'] ?? []);
    activity = Map<String, int>.from(data['activity'] ?? {});
    attempts = data['attempts'] ?? 0;
    correct = data['correct'] ?? 0;
    _serverXp = data['xp'] ?? 0;
    name = data['name'] ?? name;
    email = data['email'] ?? email;
    userId = data['id'] ?? userId;
    final pending = _unsyncedProfile;
    if (pending != null) {
      name = pending['name'];
      read.addAll(List<String>.from(pending['read']));
      hinted.addAll(List<String>.from(pending['hinted']));
    }
  }

  Future<void> signIn(
    String email,
    String password, {
    String? displayName,
  }) async {
    final remote = api!;
    final result = await remote.request(
      'POST',
      displayName == null ? '/auth/login' : '/auth/register',
      {
        'email': email.trim(),
        'password': password,
        if (displayName != null) 'name': displayName.trim(),
      },
    );
    remote.token = result['token'];
    try {
      final catalog = await remote.request('GET', '/exercises') as List;
      exercises
        ..clear()
        ..addAll(
          catalog.map((e) => Exercise.fromJson(Map<String, dynamic>.from(e))),
        );
      if (exercises.isEmpty) throw ApiException('На сервере пока нет заданий');
      _unsyncedProfile = null;
      _apply(result['profile']);
      authenticated = true;
      saveFailed = false;
      syncError = null;
      active = null;
      notifyListeners();
    } catch (_) {
      try {
        await remote.request('POST', '/auth/logout');
      } catch (_) {}
      remote.token = null;
      rethrow;
    }
  }

  Future<void> logout() async {
    await _pending;
    try {
      await api!.request('POST', '/auth/logout');
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
    }
    _clearSession();
  }

  void _clearSession() {
    api?.token = null;
    authenticated = false;
    _unsyncedProfile = null;
    _apply({'name': 'Разработчик', 'email': ''});
    userId = null;
    active = null;
    ranking = [];
    savingFavorites.clear();
    exercises.clear();
    saveFailed = false;
    syncError = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _pending;
    _apply(await api!.request('GET', '/me'));
    if (_unsyncedProfile == null) {
      saveFailed = false;
      syncError = null;
    }
    notifyListeners();
  }

  Future<void> setFavorite(String id, bool saved) async {
    if (savingFavorites.contains(id)) return;
    savingFavorites.add(id);
    notifyListeners();
    try {
      if (api != null) {
        await api!.request('PATCH', '/favorites/$id', {'saved': saved});
      }
      saved ? favorites.add(id) : favorites.remove(id);
      if (api == null) await save();
    } finally {
      savingFavorites.remove(id);
      notifyListeners();
    }
  }

  Future<void> loadRanking() async {
    final rows = await api!.request('GET', '/leaderboard') as List;
    ranking = rows
        .map(
          (e) => (
            name: e['name'] as String,
            xp: e['xp'] as int,
            you: e['you'] as bool,
          ),
        )
        .toList();
    notifyListeners();
  }

  int get xp => api != null
      ? _serverXp
      : exercises
            .where((e) => solved.contains(e.id))
            .fold(0, (v, e) => v + e.xp);
  int get level => xp ~/ 100 + 1;
  int get todayCount => activity[dayKey(_today)] ?? 0;
  int get streak {
    var date = _today;
    if (!activity.containsKey(dayKey(date))) {
      date = date.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (activity.containsKey(dayKey(date))) {
      count++;
      date = date.subtract(const Duration(days: 1));
    }
    return count;
  }

  Exercise get next => exercises.firstWhere(
    (e) => e.id == active && !solved.contains(e.id),
    orElse: () => exercises.firstWhere(
      (e) => !solved.contains(e.id),
      orElse: () => exercises.first,
    ),
  );
  void start(Exercise e) {
    active = e.id;
    notifyListeners();
  }

  Future<bool> answer(Exercise e, int line, {String? requestId}) async {
    if (api != null) {
      await _pending;
      final result = await api!.request('POST', '/exercises/${e.id}/attempts', {
        'line': line,
        'request_id': requestId ?? newRequestId(),
      });
      _apply(result['profile']);
      lastAward = result['awarded_xp'];
      if (result['correct'] == true) {
        e.applySolution(result['solution']);
        active = null;
      }
      notifyListeners();
      return result['correct'];
    }
    final success = e.errorLine == line;
    attempts++;
    lastAward = 0;
    if (success) {
      correct++;
      if (solved.add(e.id)) {
        lastAward = e.xp;
        final key = dayKey(_today);
        activity[key] = (activity[key] ?? 0) + 1;
      }
      active = null;
    }
    save();
    return success;
  }

  static String newRequestId() => List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  Future<void> save() {
    final profile = {
      'name': name,
      'read': read.toList(),
      'hinted': hinted.toList(),
    };
    if (api != null && authenticated) _unsyncedProfile = profile;
    final local = jsonEncode({
      ...profile,
      'solved': solved.toList(),
      'favorites': favorites.toList(),
      'activity': activity,
      'attempts': attempts,
      'correct': correct,
    });
    final theme = dark, size = largeCode;
    notifyListeners();
    _pending = _pending.then((_) async {
      try {
        await prefs.setBool('dark', theme);
        await prefs.setBool('largeCode', size);
        if (api != null && authenticated) {
          await api!.request('PATCH', '/me', profile);
          if (identical(_unsyncedProfile, profile)) _unsyncedProfile = null;
        } else if (api == null) {
          await prefs.setString('progress_v1', local);
        }
        saveFailed = false;
        syncError = null;
      } catch (e) {
        saveFailed = true;
        syncError = e.toString();
      }
      notifyListeners();
    });
    return _pending;
  }

  Future<void> reset() async {
    await _pending;
    if (api != null) {
      final result = await api!.request('DELETE', '/me/progress');
      _unsyncedProfile = null;
      saveFailed = false;
      syncError = null;
      _apply(result);
      active = null;
      notifyListeners();
    } else {
      solved.clear();
      read.clear();
      hinted.clear();
      activity.clear();
      attempts = 0;
      correct = 0;
      active = null;
      await save();
    }
  }
}
