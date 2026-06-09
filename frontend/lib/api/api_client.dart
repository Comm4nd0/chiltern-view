import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/animal.dart';
import '../models/care_task.dart';
import '../models/egg_record.dart';
import '../models/egg_summary.dart';
import '../models/overview.dart';
import '../models/person.dart';
import '../models/potato_planting.dart';

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
  static const Map<String, String> _jsonHeaders = {'Content-Type': 'application/json'};

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    var uri = Uri.parse('${AppConfig.baseUrl}$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query.map((k, v) => MapEntry(k, '$v')));
    }
    return uri;
  }

  void _check(http.Response res) {
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

  // --- Overview -----------------------------------------------------------
  Future<Overview> overview() async {
    final res = await _client.get(_uri('/overview/'));
    _check(res);
    return Overview.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --- Care tasks ---------------------------------------------------------
  Future<List<CareTask>> dashboard({String include = 'all', String? assignee}) async {
    final res = await _client.get(_uri('/care-tasks/dashboard/', {
      'include': include,
      if (assignee != null) 'assignee': assignee,
    }));
    _check(res);
    return _decodeList(res).map((e) => CareTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CareTask> completeTask(int id, {String? note}) async {
    final res = await _client.post(
      _uri('/care-tasks/$id/complete/'),
      headers: _jsonHeaders,
      body: jsonEncode({if (note != null && note.isNotEmpty) 'note': note}),
    );
    _check(res);
    return CareTask.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<CareTask> createCareTask({
    required String name,
    required int recurrenceIntervalDays,
    int? animal,
    int? assignee,
    String description = '',
  }) async {
    final res = await _client.post(
      _uri('/care-tasks/'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'name': name,
        'recurrence_interval_days': recurrenceIntervalDays,
        'description': description,
        if (animal != null) 'animal': animal,
        if (assignee != null) 'assignee': assignee,
      }),
    );
    _check(res);
    return CareTask.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --- People -------------------------------------------------------------
  Future<List<Person>> people() async {
    final res = await _client.get(_uri('/people/', {'ordering': 'name'}));
    _check(res);
    return _decodeList(res).map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Person> createPerson(String name) async {
    final res = await _client.post(
      _uri('/people/'),
      headers: _jsonHeaders,
      body: jsonEncode({'name': name}),
    );
    _check(res);
    return Person.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deletePerson(int id) async {
    final res = await _client.delete(_uri('/people/$id/'));
    _check(res);
  }

  // --- Animals ------------------------------------------------------------
  Future<List<Animal>> animals() async {
    final res = await _client.get(_uri('/animals/', {'active': 'true', 'ordering': 'name'}));
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
      headers: _jsonHeaders,
      body: jsonEncode({'name': name, 'species': species, 'breed': breed}),
    );
    _check(res);
    return Animal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteAnimal(int id) async {
    final res = await _client.delete(_uri('/animals/$id/'));
    _check(res);
  }

  // --- Potatoes -----------------------------------------------------------
  Future<List<PotatoPlanting>> potatoTimeline({String show = 'growing'}) async {
    final res = await _client.get(_uri('/potato-plantings/timeline/', {'show': show}));
    _check(res);
    return _decodeList(res).map((e) => PotatoPlanting.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PotatoPlanting> createPlanting({
    required String variety,
    required String category,
    required DateTime plantedOn,
    int? quantity,
    String bed = '',
  }) async {
    final res = await _client.post(
      _uri('/potato-plantings/'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'variety': variety,
        'category': category,
        'planted_on': _ymd(plantedOn),
        'bed': bed,
        if (quantity != null) 'quantity': quantity,
      }),
    );
    _check(res);
    return PotatoPlanting.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --- Eggs ---------------------------------------------------------------
  Future<EggSummary> eggSummary() async {
    final res = await _client.get(_uri('/egg-records/summary/'));
    _check(res);
    return EggSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<EggRecord>> recentEggs() async {
    final res = await _client.get(_uri('/egg-records/', {'ordering': '-date'}));
    _check(res);
    return _decodeList(res).map((e) => EggRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EggRecord> incrementEggs({int count = 1, String? source}) async {
    final res = await _client.post(
      _uri('/egg-records/increment/'),
      headers: _jsonHeaders,
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
}
