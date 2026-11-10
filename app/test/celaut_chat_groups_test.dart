import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/chat_groups.dart';
import 'package:argus_wallet/celaut/conversations.dart';
import 'package:argus_wallet/celaut/stopped_filter.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/chats_screen.dart';
import 'package:argus_wallet/ui/celaut/instance_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

InstanceListView _instance(String id, String name, {int startedAt = 100}) => InstanceListView(
      instanceId: id,
      peerId: 'aa' * 32,
      address: 'node.example:53460',
      serviceId: '65' * 32,
      slots: Uint16List.fromList([8080]),
      chatSlots: Uint16List.fromList([8080]),
      cardsSlots: Uint16List(0),
      webSlots: Uint16List.fromList([]),
      startedAt: startedAt,
      startChargeMu: '1000',
      name: name,
      alias: '',
      title: '',
      refundMu: '',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the group texts exist in English and Spanish', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final es = lookupAppLocalizations(const Locale('es'));
    expect(en.chatsGroupsDeleteTitle('X'), 'Delete group X?');
    expect(es.chatsGroupsDeleteTitle('X'), '¿Eliminar el grupo X?');
    expect(en.chatsGroupsNew, isNot(es.chatsGroupsNew));
  });

  group('ChatGroups', () {
    test('defaults: no group, flat list', () async {
      final g = ChatGroups();
      await g.load();
      expect(g.groups, isEmpty);
      expect(g.grouped, isFalse);
      expect(g.groupOf('a'), isNull);
    });

    test('create, rename, move, collapse and delete persist', () async {
      final g = ChatGroups();
      final work = (await g.create('  Work   chats '))!;
      final fun = (await g.create('Fun'))!;
      expect(work.name, 'Work chats');
      expect(work.id, isNot(fun.id));
      expect(await g.create('   '), isNull);
      await g.move('a', work.id);
      await g.move('b', work.id);
      await g.move('c', fun.id);
      await g.rename(fun.id, 'Games');
      await g.setCollapsed(work.id, true);
      await g.setGrouped(true);

      final q = ChatGroups();
      await q.load();
      expect(q.grouped, isTrue);
      expect([for (final x in q.groups) x.name], ['Work chats', 'Games']);
      expect(q.groupOf('a')?.id, work.id);
      expect(q.groupOf('c')?.name, 'Games');
      expect(q.isCollapsed(work.id), isTrue);
      expect(q.isCollapsed(fun.id), isFalse);

      // A conversation is in one group at most.
      await q.move('a', fun.id);
      expect(q.groupOf('a')?.id, fun.id);
      await q.move('a', null);
      expect(q.groupOf('a'), isNull);

      // Deleting a group frees its conversations.
      await q.delete(work.id);
      expect(q.groupOf('b'), isNull);
      expect(q.groups.length, 1);
      final r = ChatGroups();
      await r.load();
      expect(r.groups.length, 1);
      expect(r.isCollapsed(work.id), isFalse);
    });

    test('moving to a group that does not exist changes nothing; a blank name keeps the old', () async {
      final g = ChatGroups();
      final a = (await g.create('A'))!;
      await g.move('x', 'nope');
      expect(g.groupOf('x'), isNull);
      await g.rename(a.id, '  ');
      expect(g.group(a.id)?.name, 'A');
    });

    test('a long name is cut', () {
      expect(ChatGroups.cleanName('x' * 100).length, ChatGroups.maxNameChars);
    });

    test('a damaged stored value is ignored', () async {
      SharedPreferences.setMockInitialValues({'chat_groups_v1': '{not json'});
      final g = ChatGroups();
      await g.load();
      expect(g.groups, isEmpty);
      SharedPreferences.setMockInitialValues({
        'chat_groups_v1': '{"grouped":true,"groups":[{"id":"g1","name":"A"},5],"of":{"a":"g1","b":"gone"},"collapsed":["g1","gone"]}',
      });
      final h = ChatGroups();
      await h.load();
      expect(h.groups.length, 1);
      expect(h.groupOf('a')?.name, 'A');
      expect(h.groupOf('b'), isNull);
      expect(h.isCollapsed('g1'), isTrue);
    });
  });

  group('the list in groups', () {
    late ChatGroups groups;
    late StoppedFilter filter;
    final db = [_instance('i1', 'Alpha', startedAt: 300), _instance('i2', 'Beta', startedAt: 200), _instance('i3', 'Gamma', startedAt: 100)];

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: false),
          home: Scaffold(
            body: InstanceList(
              chats: true,
              notes: ConversationNotes(),
              groups: groups,
              filter: filter,
              load: () => List.of(db),
              loadStatus: (_) async => throw Exception('x'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() async {
      groups = ChatGroups();
      filter = StoppedFilter();
      await filter.set(false);
    });

    testWidgets('flat by default, even with groups', (tester) async {
      final g = (await groups.create('Team'))!;
      await groups.move('i1', g.id);
      await open(tester);
      expect(find.byKey(Key('group-header-${g.id}')), findsNothing);
      for (final id in ['i1', 'i2', 'i3']) {
        expect(find.byKey(Key('chats-row-$id')), findsOneWidget);
      }
    });

    testWidgets('grouped: headers, counts, collapse and expand', (tester) async {
      final g = (await groups.create('Team'))!;
      await groups.move('i1', g.id);
      await groups.move('i2', g.id);
      await groups.setGrouped(true);
      await open(tester);
      expect(find.byKey(Key('group-header-${g.id}')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(Key('group-count-${g.id}'))).data, '2');
      expect(find.byKey(const Key('group-ungrouped')), findsOneWidget);
      expect(find.byKey(const Key('chats-row-i3')), findsOneWidget);

      await tester.tap(find.byKey(Key('group-header-${g.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-row-i1')), findsNothing);
      expect(find.byKey(const Key('chats-row-i3')), findsOneWidget);
      expect(groups.isCollapsed(g.id), isTrue);

      await tester.tap(find.byKey(Key('group-header-${g.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-row-i1')), findsOneWidget);
    });

    testWidgets('long press, Move to a group: new group, then another and none', (tester) async {
      await groups.setGrouped(true);
      await open(tester);
      await tester.longPress(find.byKey(const Key('chats-row-i2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-move')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-move-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('group-name-field')), 'Pals');
      await tester.tap(find.byKey(const Key('group-name-ok')));
      await tester.pumpAndSettle();
      expect(groups.groupOf('i2')?.name, 'Pals');
      final id = groups.groupOf('i2')!.id;
      expect(find.byKey(Key('group-name-$id')), findsOneWidget);

      await tester.longPress(find.byKey(const Key('chats-row-i2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-move')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-move-none')));
      await tester.pumpAndSettle();
      expect(groups.groupOf('i2'), isNull);
    });

    testWidgets('the menu of a group renames and deletes it', (tester) async {
      final g = (await groups.create('Team'))!;
      await groups.move('i1', g.id);
      await groups.setGrouped(true);
      await open(tester);

      await tester.tap(find.byKey(Key('group-menu-${g.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('group-rename-${g.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('group-name-field')), 'Crew');
      await tester.tap(find.byKey(const Key('group-name-ok')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(Key('group-name-${g.id}'))).data, 'Crew');

      await tester.tap(find.byKey(Key('group-menu-${g.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('group-delete-${g.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('group-delete-ok')));
      await tester.pumpAndSettle();
      expect(groups.groups, isEmpty);
      // The conversation stays.
      expect(find.byKey(const Key('chats-row-i1')), findsOneWidget);
    });
  });

  testWidgets('the Chats screen menu switches the view and makes a group', (tester) async {
    final groups = ChatGroups();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: argusTheme(watchful: false),
        home: ChatsScreen(
          notes: ConversationNotes(),
          groups: groups,
          list: (key, empty) => InstanceList(
            key: key,
            chats: true,
            empty: empty,
            notes: ConversationNotes(),
            groups: groups,
            filter: StoppedFilter(),
            load: () => [_instance('i1', 'Alpha')],
            loadStatus: (_) async => throw Exception('x'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chats-groups-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chats-groups-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-name-field')), 'Team');
    await tester.tap(find.byKey(const Key('group-name-ok')));
    await tester.pumpAndSettle();
    expect(groups.groups.single.name, 'Team');

    await tester.tap(find.byKey(const Key('chats-groups-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chats-groups-view')));
    await tester.pumpAndSettle();
    expect(groups.grouped, isTrue);
    expect(find.byKey(Key('group-header-${groups.groups.single.id}')), findsOneWidget);
  });
}
