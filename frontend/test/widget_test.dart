import 'package:flutter_test/flutter_test.dart';

import 'package:chiltern_view/models/animal.dart';
import 'package:chiltern_view/models/auth_user.dart';
import 'package:chiltern_view/models/care_task.dart';
import 'package:chiltern_view/models/egg_summary.dart';
import 'package:chiltern_view/models/overview.dart';
import 'package:chiltern_view/models/crop.dart';
import 'package:chiltern_view/models/person.dart';

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

    CareTask feedTask({int times = 1, int done = 0, int everyDays = 1, String? dueDate}) =>
        CareTask.fromJson({
          'id': 2,
          'name': 'Feed the dog',
          'recurrence_interval_days': everyDays,
          'times_per_day': times,
          'times_done_today': done,
          'due_date': dueDate,
          'next_due': '2026-01-01',
          'days_overdue': 0,
          'status': 'due_today',
        });

    test('labels recurrence, matching the web wording', () {
      expect(feedTask(everyDays: 1).recurrenceLabel, 'daily');
      expect(feedTask(everyDays: 3).recurrenceLabel, 'every 3 days');
      expect(feedTask(times: 4).recurrenceLabel, '4× a day');
      expect(feedTask(times: 2, everyDays: 3).recurrenceLabel, 'every 3 days, 2× a day');
      expect(feedTask(dueDate: '2026-01-01').recurrenceLabel, 'one-off');
    });

    test('shows progress through a several-times-a-day task', () {
      expect(feedTask(times: 4, done: 0).dueLabel, 'Due today');
      expect(feedTask(times: 4, done: 2).dueLabel, 'Due today (2 of 4 done)');
      // Once a day: no counter noise.
      expect(feedTask(times: 1, done: 1).dueLabel, 'Due today');
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

  test('Crop parses stages and progress', () {
    final crop = Crop.fromJson({
      'id': 1,
      'crop': 'carrots',
      'crop_label': 'Carrots',
      'variety': 'Nantes',
      'planted_on': '2026-03-01',
      'quantity': null,
      'bed': 'Bed 2',
      'expected_harvest': null,
      'harvested_on': null,
      'yield_kg': null,
      'notes': '',
      'estimated_harvest': '2026-05-15',
      'current_stage': 'Thinning',
      'progress': 0.5,
      'stages': [
        {'label': 'Sown', 'date': '2026-03-01'},
        {'label': 'Thinning', 'date': '2026-04-10'},
      ],
    });
    expect(crop.crop, 'carrots');
    expect(crop.cropLabel, 'Carrots');
    expect(crop.variety, 'Nantes');
    expect(crop.stages.length, 2);
    expect(crop.currentStage, 'Thinning');
    expect(crop.progress, 0.5);
    expect(crop.isHarvested, isFalse);
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

  test('Overview parses the aggregate payload', () {
    final o = Overview.fromJson({
      'tasks': {
        'overdue': 2,
        'due_today': 1,
        'upcoming': 3,
        'per_person': {'Marco': 3, 'Claire': 2, 'Unassigned': 1},
        'top': [
          {
            'id': 1,
            'name': 'Worm the goats',
            'assignee_name': 'Marco',
            'days_overdue': 30,
            'status': 'overdue',
          },
        ],
      },
      'animals': {
        'total': 3,
        'by_species': {'Goat': 1, 'Chicken': 1, 'Pig': 1},
      },
      'crops': {
        'growing': 3,
        'next_harvest': {'label': 'Carrots', 'date': '2026-07-14'},
      },
      'eggs': {'today': 5, 'this_week': 12},
    });
    expect(o.tasksOverdue, 2);
    expect(o.perPerson['Marco'], 3);
    expect(o.topTasks.single.dueLabel, '30d overdue');
    expect(o.animalsTotal, 3);
    expect(o.cropsGrowing, 3);
    expect(o.nextHarvest?.label, 'Carrots');
    expect(o.eggsThisWeek, 12);
  });

  test('AuthUser parses the login/me payload', () {
    final user = AuthUser.fromJson({
      'id': 3,
      'username': 'marco',
      'person_id': 7,
      'person_name': 'Marco',
    });
    expect(user.id, 3);
    expect(user.username, 'marco');
    expect(user.personId, 7);
    expect(user.personName, 'Marco');

    // An account with no linked Person yet.
    final unlinked = AuthUser.fromJson({'id': 4, 'username': 'claire'});
    expect(unlinked.personId, isNull);
    expect(unlinked.personName, isNull);
  });

  test('Animal parses status and date of birth', () {
    final goat = Animal.fromJson({
      'id': 1,
      'name': 'Daisy',
      'species': 'goat',
      'species_display': 'Goat',
      'breed': 'Saanen',
      'date_of_birth': '2022-04-01',
      'active': true,
    });
    expect(goat.speciesDisplay, 'Goat');
    expect(goat.active, isTrue);
    expect(goat.dateOfBirth, DateTime(2022, 4, 1));

    // Missing optional fields: dob null, active defaults to true.
    final minimal = Animal.fromJson({
      'id': 2,
      'name': 'Hen',
      'species': 'chicken',
      'species_display': 'Chicken',
      'breed': '',
    });
    expect(minimal.dateOfBirth, isNull);
    expect(minimal.active, isTrue);
  });
}
