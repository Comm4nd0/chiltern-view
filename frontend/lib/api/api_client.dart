import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/animal.dart';
import '../models/auth_user.dart';
import '../models/bed_history.dart';
import '../models/care_task.dart';
import '../models/crop.dart';
import '../models/crop_catalog.dart';
import '../models/egg_record.dart';
import '../models/egg_summary.dart';
import '../models/egg_trend.dart';
import '../models/log_entry.dart';
import '../models/overview.dart';
import '../models/person.dart';

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'Request failed ($statusCode): $body';
}

/// Thin client over the chiltern_view DRF API.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Invoked when an authenticated request returns 401 (token missing, expired,
  /// or revoked) so the app can drop credentials and return to the login screen.
  static void Function()? onUnauthorized;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    var uri = Uri.parse('${AppConfig.baseUrl}$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query.map((k, v) => MapEntry(k, '$v')));
    }
    return uri;
  }

  /// Headers for every request: the auth token when signed in, plus a JSON
  /// content-type for requests that carry a body.
  Map<String, String> _headers({bool json = false}) {
    final token = AppConfig.authToken;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  void _check(http.Response res) {
    if (res.statusCode == 401) {
      onUnauthorized?.call();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, res.body);
    }
  }

  /// DRF list endpoints are paginated ({results: [...]}); custom actions are not.
  List<dynamic> _decodeList(http.Response res) {
    final dynamic body = jsonDecode(res.body);
    if (body is Map<String, dynamic> && body.containsKey('results')) {
      return body['results'] as List<dynamic>;
    }
    return body as List<dynamic>;
  }

  // --- Auth ---------------------------------------------------------------
  /// Exchange username/password for a token and persist it via AppConfig.
  /// A non-2xx here means bad credentials (not session expiry), so it is NOT
  /// routed through [onUnauthorized].
  Future<AuthUser> login(String username, String password) async {
    final res = await _client.post(
      _uri('/auth/login/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, res.body);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await AppConfig.setAuth(
      token: data['token'] as String,
      username: user.username,
      personId: user.personId,
      personName: user.personName,
    );
    return user;
  }

  /// Revoke the token server-side, then forget it locally (always).
  Future<void> logout() async {
    try {
      await _client.post(_uri('/auth/logout/'), headers: _headers());
    } catch (_) {
      // Ignore network errors — local credentials are cleared regardless.
    }
    await AppConfig.clearAuth();
  }

  Future<AuthUser> me() async {
    final res = await _client.get(_uri('/auth/me/'), headers: _headers());
    _check(res);
    return AuthUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --- Overview -----------------------------------------------------------
  Future<Overview> overview() async {
    final res = await _client.get(_uri('/overview/'), headers: _headers());
    _check(res);
    return Overview.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --- Care tasks ---------------------------------------------------------
  /// [animal] narrows to one animal's tasks, including its species' shared
  /// routine (flock jobs), for the animal detail screen.
  Future<List<CareTask>> dashboard({String include = 'all', String? assignee, int? animal}) async {
    final res = await _client.get(
      _uri('/care-tasks/dashboard/', {
        'include': include,
        if (assignee != null) 'assignee': assignee,
        if (animal != null) 'animal': animal,
      }),
      headers: _headers(),
    );
    _check(res);
    return _decodeList(res).map((e) => CareTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CareTask> completeTask(int id, {String? note}) async {
    final res = await _client.post(
      _uri('/care-tasks/$id/complete/'),
      headers: _headers(json: true),
      body: jsonEncode({if (note != null && note.isNotEmpty) 'note': note}),
    );
    _check(res);
    return CareTask.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Undo an accidental "Done": restores the task's prior schedule.
  Future<CareTask> uncompleteTask(int id) async {
    final res = await _client.post(
      _uri('/care-tasks/$id/uncomplete/'),
      headers: _headers(json: true),
      body: '{}',
    );
    _check(res);
    return CareTask.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<CareTask> createCareTask({
    required String name,
    int recurrenceIntervalDays = 7,
    int timesPerDay = 1,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    int? animal,
    String species = '',
    int? assignee,
    String description = '',
  }) async {
    final res = await _client.post(
      _uri('/care-tasks/'),
      headers: _headers(json: true),
      body: jsonEncode({
        'name': name,
        'recurrence_interval_days': recurrenceIntervalDays,
        'times_per_day': timesPerDay,
        'due_date': dueDate != null ? _ymd(dueDate) : null,
        'due_time': dueTime != null ? _hm(dueTime) : null,
        'species': species,
        'description': description,
        if (animal != null) 'animal': animal,
        if (assignee != null) 'assignee': assignee,
      }),
    );
    _check(res);
    return CareTask.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Edit an existing task. Sends only the form-controlled fields, so an unset
  /// animal/assignee (null) clears the link rather than leaving it untouched.
  Future<CareTask> updateCareTask(
    int id, {
    required String name,
    required int recurrenceIntervalDays,
    int timesPerDay = 1,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    int? animal,
    String species = '',
    int? assignee,
  }) async {
    final res = await _client.patch(
      _uri('/care-tasks/$id/'),
      headers: _headers(json: true),
      body: jsonEncode({
        'name': name,
        'recurrence_interval_days': recurrenceIntervalDays,
        'times_per_day': timesPerDay,
        'due_date': dueDate != null ? _ymd(dueDate) : null, // null clears => repeats
        'due_time': dueTime != null ? _hm(dueTime) : null, // null clears => anytime
        'animal': animal, // null clears the individual link
        'species': species, // '' clears the type link
        'assignee': assignee,
      }),
    );
    _check(res);
    return CareTask.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteCareTask(int id) async {
    final res = await _client.delete(_uri('/care-tasks/$id/'), headers: _headers());
    _check(res);
  }

  // --- People -------------------------------------------------------------
  Future<List<Person>> people() async {
    final res = await _client.get(_uri('/people/', {'ordering': 'name'}), headers: _headers());
    _check(res);
    return _decodeList(res).map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Person> createPerson(String name) async {
    final res = await _client.post(
      _uri('/people/'),
      headers: _headers(json: true),
      body: jsonEncode({'name': name}),
    );
    _check(res);
    return Person.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deletePerson(int id) async {
    final res = await _client.delete(_uri('/people/$id/'), headers: _headers());
    _check(res);
  }

  // --- Animals ------------------------------------------------------------
  /// All animals (active and retired) so the dashboard can show each status.
  Future<List<Animal>> animals() async {
    final res = await _client.get(_uri('/animals/', {'ordering': 'name'}), headers: _headers());
    _check(res);
    return _decodeList(res).map((e) => Animal.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Animal> createAnimal({
    required String name,
    required String species,
    String breed = '',
  }) async {
    final res = await _client.post(
      _uri('/animals/'),
      headers: _headers(json: true),
      body: jsonEncode({'name': name, 'species': species, 'breed': breed}),
    );
    _check(res);
    return Animal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Animal> updateAnimal(
    int id, {
    required String name,
    required String species,
    String breed = '',
    bool? active,
  }) async {
    final res = await _client.patch(
      _uri('/animals/$id/'),
      headers: _headers(json: true),
      body: jsonEncode({
        'name': name,
        'species': species,
        'breed': breed,
        if (active != null) 'active': active,
      }),
    );
    _check(res);
    return Animal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteAnimal(int id) async {
    final res = await _client.delete(_uri('/animals/$id/'), headers: _headers());
    _check(res);
  }

  Future<Animal> animal(int id) async {
    final res = await _client.get(_uri('/animals/$id/'), headers: _headers());
    _check(res);
    return Animal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --- Journal --------------------------------------------------------------
  /// One page of the journal, newest first (DRF paginates at 50). [types] is a
  /// CSV of entry types, e.g. 'health,feeding' — used to hide task completions.
  Future<PagedLogEntries> logEntries({int? animal, String? types, int page = 1}) async {
    final res = await _client.get(
      _uri('/log-entries/', {
        if (animal != null) 'animal': animal,
        if (types != null && types.isNotEmpty) 'types': types,
        if (page > 1) 'page': page,
      }),
      headers: _headers(),
    );
    _check(res);
    final dynamic body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) {
      return PagedLogEntries(
        entries: (body['results'] as List<dynamic>)
            .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasMore: body['next'] != null,
      );
    }
    return PagedLogEntries(
      entries: (body as List<dynamic>)
          .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: false,
    );
  }

  Future<LogEntry> createLogEntry({
    required String entryType,
    required String note,
    int? animal,
    DateTime? occurredOn,
  }) async {
    final res = await _client.post(
      _uri('/log-entries/'),
      headers: _headers(json: true),
      body: jsonEncode({
        'entry_type': entryType,
        'note': note,
        if (animal != null) 'animal': animal,
        if (occurredOn != null) 'occurred_on': _ymd(occurredOn),
      }),
    );
    _check(res);
    return LogEntry.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<LogEntry> updateLogEntry(
    int id, {
    required String entryType,
    required String note,
    DateTime? occurredOn,
  }) async {
    final res = await _client.patch(
      _uri('/log-entries/$id/'),
      headers: _headers(json: true),
      body: jsonEncode({
        'entry_type': entryType,
        'note': note,
        if (occurredOn != null) 'occurred_on': _ymd(occurredOn),
      }),
    );
    _check(res);
    return LogEntry.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteLogEntry(int id) async {
    final res = await _client.delete(_uri('/log-entries/$id/'), headers: _headers());
    _check(res);
  }

  // --- Crops --------------------------------------------------------------
  Future<List<Crop>> crops({String show = 'growing'}) async {
    final res = await _client.get(_uri('/crops/timeline/', {'show': show}), headers: _headers());
    _check(res);
    return _decodeList(res).map((e) => Crop.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CropCatalogEntry>> cropCatalog() async {
    final res = await _client.get(_uri('/crops/catalog/'), headers: _headers());
    _check(res);
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => CropCatalogEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Per-bed planting history, for crop-rotation warnings in the crop sheet.
  Future<List<BedHistory>> beds() async {
    final res = await _client.get(_uri('/crops/beds/'), headers: _headers());
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['beds'] as List<dynamic>)
        .map((e) => BedHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Crop> createCrop({
    required String crop,
    String variety = '',
    required DateTime plantedOn,
    String bed = '',
    int? quantity,
    DateTime? expectedHarvest,
    String notes = '',
  }) async {
    final res = await _client.post(
      _uri('/crops/'),
      headers: _headers(json: true),
      body: jsonEncode({
        'crop': crop,
        'variety': variety,
        'planted_on': _ymd(plantedOn),
        'bed': bed,
        'quantity': quantity,
        'expected_harvest': expectedHarvest != null ? _ymd(expectedHarvest) : null,
        'notes': notes,
      }),
    );
    _check(res);
    return Crop.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Edit a planting. Sends all form-controlled fields, so cleared optional
  /// values (quantity, expected harvest) are unset rather than left untouched.
  Future<Crop> updateCrop(
    int id, {
    required String crop,
    String variety = '',
    required DateTime plantedOn,
    String bed = '',
    int? quantity,
    DateTime? expectedHarvest,
    String notes = '',
  }) async {
    final res = await _client.patch(
      _uri('/crops/$id/'),
      headers: _headers(json: true),
      body: jsonEncode({
        'crop': crop,
        'variety': variety,
        'planted_on': _ymd(plantedOn),
        'bed': bed,
        'quantity': quantity,
        'expected_harvest': expectedHarvest != null ? _ymd(expectedHarvest) : null,
        'notes': notes,
      }),
    );
    _check(res);
    return Crop.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteCrop(int id) async {
    final res = await _client.delete(_uri('/crops/$id/'), headers: _headers());
    _check(res);
  }

  /// Record a harvest. The backend also retires the crop's auto watering and
  /// harvest reminders, so callers should re-sync scheduled notifications.
  Future<Crop> harvestCrop(int id, {DateTime? date, double? yieldKg, String? note}) async {
    final res = await _client.post(
      _uri('/crops/$id/harvest/'),
      headers: _headers(json: true),
      body: jsonEncode({
        if (date != null) 'date': _ymd(date),
        if (yieldKg != null) 'yield_kg': '$yieldKg',
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );
    _check(res);
    return Crop.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --- Eggs ---------------------------------------------------------------
  Future<EggSummary> eggSummary() async {
    final res = await _client.get(_uri('/egg-records/summary/'), headers: _headers());
    _check(res);
    return EggSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<EggRecord>> recentEggs() async {
    final res = await _client.get(_uri('/egg-records/', {'ordering': '-date'}), headers: _headers());
    _check(res);
    return _decodeList(res).map((e) => EggRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Daily egg totals over the last [days] days (zero-filled), for the trend chart.
  Future<EggTrend> eggTrend({int days = 30}) async {
    final res = await _client.get(_uri('/egg-records/trend/', {'days': days}), headers: _headers());
    _check(res);
    return EggTrend.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<EggRecord> incrementEggs({int count = 1, String? source}) async {
    final res = await _client.post(
      _uri('/egg-records/increment/'),
      headers: _headers(json: true),
      body: jsonEncode({
        'count': count,
        if (source != null && source.isNotEmpty) 'source': source,
      }),
    );
    _check(res);
    return EggRecord.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
