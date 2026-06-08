import 'package:flutter_test/flutter_test.dart';

import 'package:chiltern_view/models/care_task.dart';
import 'package:chiltern_view/models/egg_summary.dart';
import 'package:chiltern_view/models/person.dart';
import 'package:chiltern_view/models/potato_planting.dart';

void main() {
  group('CareTask', () {
    CareTask fromDaysOverdue(int days, String status) => CareTask.fromJson({
          'id': 1,
          'name': 'Worm the goats',
          'description': '',
          'animal': null,
          'animal_name': null,
          'recurrence_interval_days': 90,
          'last_completed': null,
          'active': true,
          'next_due': '2026-01-01',
          'days_overdue': days,
          'status': status,
        });

    test('labels an overdue task', () {
      expect(fromDaysOverdue(3, 'overdue').dueLabel, '3 days overdue');
      expect(fromDaysOverdue(1, 'overdue').dueLabel, '1 day overdue');
    });

    test('labels a due-today task', () {
      expect(fromDaysOverdue(0, 'due_today').dueLabel, 'Due today');
    });

    test('labels an upcoming task', () {
      expect(fromDaysOverdue(-5, 'upcoming').dueLabel, 'Due in 5 days');
    });
  });

  test('EggSummary parses snake_case keys', () {
    final summary = EggSummary.fromJson({
      'today': 5,
      'this_week': 20,
      'this_month': 80,
      'total': 365,
    });
    expect(summary.today, 5);
    expect(summary.thisWeek, 20);
    expect(summary.thisMonth, 80);
    expect(summary.total, 365);
  });

  test('PotatoPlanting parses stages and progress', () {
    final planting = PotatoPlanting.fromJson({
      'id': 1,
      'variety': 'Charlotte',
      'category': 'first_early',
      'category_display': 'First early',
      'planted_on': '2026-03-01',
      'quantity': null,
      'bed': 'Bed 2',
      'expected_harvest': null,
      'harvested_on': null,
      'yield_kg': null,
      'notes': '',
      'estimated_harvest': '2026-05-15',
      'current_stage': 'Flowering',
      'progress': 0.5,
      'stages': [
        {'label': 'Planted', 'date': '2026-03-01'},
        {'label': 'Flowering', 'date': '2026-04-10'},
      ],
    });
    expect(planting.variety, 'Charlotte');
    expect(planting.stages.length, 2);
    expect(planting.currentStage, 'Flowering');
    expect(planting.progress, 0.5);
    expect(planting.isHarvested, isFalse);
  });

  test('CareTask parses assignee', () {
    final task = CareTask.fromJson({
      'id': 1,
      'name': 'Lock up hens',
      'description': '',
      'animal': null,
      'animal_name': null,
      'assignee': 7,
      'assignee_name': 'Marco',
      'recurrence_interval_days': 1,
      'last_completed': null,
      'active': true,
      'next_due': '2026-01-02',
      'days_overdue': 0,
      'status': 'due_today',
    });
    expect(task.assignee, 7);
    expect(task.assigneeName, 'Marco');

    // Unassigned task: missing keys decode to null.
    final unassigned = CareTask.fromJson({
      'id': 2,
      'name': 'Mend fence',
      'next_due': '2026-01-02',
      'days_overdue': -1,
      'status': 'upcoming',
    });
    expect(unassigned.assignee, isNull);
    expect(unassigned.assigneeName, isNull);
  });

  test('Person parses and compares by id', () {
    final a = Person.fromJson({'id': 7, 'name': 'Marco'});
    final b = Person.fromJson({'id': 7, 'name': 'Marco (renamed)'});
    final c = Person.fromJson({'id': 8, 'name': 'Sam'});
    expect(a, equals(b)); // identity by id — needed for dropdown matching
    expect(a, isNot(equals(c)));
  });
}
