import 'package:easyclaim/core/api/api_client.dart';
import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/core/realtime/live_toaster.dart';
import 'package:easyclaim/core/realtime/live_toasts.dart';
import 'package:easyclaim/core/realtime/realtime_service.dart';
import 'package:easyclaim/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'support/fake_realtime.dart';

// Live channel (docs/API_CONTRACT.md, "Live updates"): ticket → WebSocket, notices parsed into
// events, a resync on every (re)connect, reconnect with backoff, quiet offline without a live
// channel (503), ping keep-alive, and an instant sign-out on session.revoked.

Future<void> _pumpFor(WidgetTester tester, Duration d) async {
  final steps = d.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeBackend backend;

  setUp(() {
    Session.instance.signOut();
    backend = FakeBackend()..install();
    ApiClient.lastWriteAt = null;
  });

  group('RealtimeEvent', () {
    test('parses notices; ignores pong, non-JSON and untyped frames', () {
      final e = RealtimeEvent.parse('{"type":"consent.updated","consentId":"cst_1","subjectType":"claim","subjectId":"claim_1a2b3c4d9","status":"viewed","at":"2026-09-27T10:00:00Z"}')!;
      expect(e.type, 'consent.updated');
      expect(e.status, 'viewed');
      expect(e.at, DateTime.utc(2026, 9, 27, 10));
      expect(e.isClaimEvent, isTrue);
      expect(e.isLinkEvent, isFalse);
      expect(e.concernsClaim('claim_1a2b3c4d9'), isTrue);
      expect(RealtimeEvent.parse('pong'), isNull);
      expect(RealtimeEvent.parse('not json'), isNull);
      expect(RealtimeEvent.parse('{"stage":"Review"}'), isNull);
      final link = RealtimeEvent.parse('{"type":"consent.updated","subjectType":"policy_link","subjectId":"plr_1","status":"signed"}')!;
      expect(link.isLinkEvent, isTrue);
      expect(link.concernsRequest('plr_1'), isTrue);
      expect(shortClaimId('claim_1a2b3c4d5e6f'), '1A2B3C4D');
    });
  });

  group('RealtimeService', () {
    testWidgets('connects with a ticket, emits resync, delivers notices and pings every 25 s', (tester) async {
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      final live = FakeRealtime(backend);
      final events = <RealtimeEvent>[];
      final sub = live.service.events.listen(events.add);
      live.connect();
      await tester.pump(const Duration(milliseconds: 50));

      expect(live.service.status.value, RealtimeStatus.live);
      expect(backend.last('POST /realtime/ticket')!.headers['Authorization'], 'Bearer test-token-assessor_a1');
      expect(live.uris.single.toString(), 'ws://test.local/api/v1/realtime/connect?ticket=tkt-1');
      expect(events.map((e) => e.type), [RealtimeEvent.resyncType]);

      live.socket.pushRaw('pong');
      live.push('claim.updated', {'claimId': 'claim_1', 'stage': 'Screening'});
      await tester.pump();
      expect(events.map((e) => e.type), [RealtimeEvent.resyncType, 'claim.updated']);
      expect(events.last.stage, 'Screening');

      await _pumpFor(tester, const Duration(seconds: 25));
      expect(live.socket.sent, contains('ping'));

      sub.cancel();
      live.dispose();
    });

    testWidgets('reconnects with a fresh ticket after the connection drops, then resyncs again', (tester) async {
      signInAs('usr_mike', 'CUSTOMER');
      final live = FakeRealtime(backend);
      final events = <RealtimeEvent>[];
      final sub = live.service.events.listen(events.add);
      live.connect();
      await tester.pump(const Duration(milliseconds: 50));
      expect(live.tickets, 1);

      live.socket.serverClose(1006);
      await tester.pump();
      expect(live.service.status.value, RealtimeStatus.offline);

      await _pumpFor(tester, const Duration(milliseconds: 1100)); // first backoff step: 1 s
      expect(live.tickets, 2);
      expect(live.sockets, hasLength(2));
      expect(live.uris.last.queryParameters['ticket'], 'tkt-2');
      expect(live.service.status.value, RealtimeStatus.live);
      expect(events.where((e) => e.isResync), hasLength(2));

      sub.cancel();
      live.dispose();
    });

    testWidgets('no live channel on the server (503): stays offline quietly and retries later', (tester) async {
      signInAs('usr_mike', 'CUSTOMER');
      final service = RealtimeService(connector: (_) => throw StateError('must not connect without a ticket'));
      service.attach();
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.status.value, RealtimeStatus.offline);
      final tries = backend.requests.where((r) => r.path == '/realtime/ticket').length;
      expect(tries, 1);
      await _pumpFor(tester, const Duration(milliseconds: 1100));
      expect(backend.requests.where((r) => r.path == '/realtime/ticket').length, 2);
      expect(Session.instance.isActive, isTrue);
      service.dispose();
    });

    testWidgets('signing out closes the socket; signing in again reconnects', (tester) async {
      signInAs('usr_mike', 'CUSTOMER');
      final live = FakeRealtime(backend);
      live.connect();
      await tester.pump(const Duration(milliseconds: 50));
      final first = live.socket;
      Session.instance.signOut();
      await tester.pump();
      expect(first.closedByClient, isTrue);
      expect(live.service.status.value, RealtimeStatus.offline);
      signInAs('usr_mike', 'CUSTOMER');
      await tester.pump(const Duration(milliseconds: 50));
      expect(live.sockets, hasLength(2));
      live.dispose();
    });

    testWidgets('session.revoked signs the user out and the sign-in screen explains why', (tester) async {
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      final live = FakeRealtime(backend);
      await tester.pumpWidget(const EasyClaimApp(initialScreen: Scaffold(body: Text('Working on claims'))));
      live.connect();
      await tester.pump(const Duration(milliseconds: 50));

      live.push('session.revoked', {'reason': 'account_disabled'});
      live.socket.serverClose(4001);
      await _pumpFor(tester, const Duration(seconds: 1));

      expect(Session.instance.isActive, isFalse);
      expect(Session.instance.signedOutByUser, isFalse);
      expect(Session.instance.endReason, Session.reasonRevoked);
      expect(find.text('Working on claims'), findsNothing);
      expect(find.text(revokedNotice), findsOneWidget);
      expect(live.service.status.value, RealtimeStatus.offline);
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(live.tickets, 1, reason: 'no reconnect after a revocation');
      live.dispose();
    });

    testWidgets('any other session end keeps the generic notice', (tester) async {
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      await tester.pumpWidget(const EasyClaimApp(initialScreen: Scaffold(body: Text('Working on claims'))));
      Session.instance.signOut(byUser: false);
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.text(sessionEndedNotice), findsOneWidget);
    });
  });

  group('live toasts', () {
    AuthActor actor(String role) => AuthActor(id: 'u1', role: role, tenantId: 'ins_discovery');
    RealtimeEvent consent(String status, {String subjectType = 'claim', String subjectId = 'claim_1a2b3c4d9'}) =>
        RealtimeEvent('consent.updated', {'consentId': 'cst_1', 'subjectType': subjectType, 'subjectId': subjectId, 'status': status});

    test('staff sentences name the claim by its short id', () {
      final staff = actor('ASSESSOR');
      expect(liveToastText(consent('signed'), staff), 'Customer signed the POPIA mandate · claim 1A2B3C4D');
      expect(liveToastText(consent('viewed'), staff), 'Customer is reading the POPIA mandate · claim 1A2B3C4D');
      expect(liveToastText(consent('declined'), staff), 'Customer declined the POPIA mandate · claim 1A2B3C4D');
      expect(liveToastText(consent('withdrawn', subjectType: 'policy_link', subjectId: 'plr_1'), staff), 'Customer withdrew POPIA consent · policy request');
      expect(liveToastText(const RealtimeEvent('link.updated', {'requestId': 'plr_1', 'change': 'created'}), staff), 'New policy request');
      expect(liveToastText(const RealtimeEvent('link.updated', {'requestId': 'plr_1', 'change': 'document_uploaded'}), staff),
          'Customer uploaded a document · policy request');
      expect(
        combinedToastText([
          const RealtimeEvent('claim.message', {'claimId': 'claim_1a2b3c4d9', 'from': 'customer'}),
          const RealtimeEvent('claim.updated', {'claimId': 'claim_1a2b3c4d9', 'stage': 'Screening'}),
        ], staff),
        'Customer replied to your information request · claim 1A2B3C4D',
      );
      expect(liveToastText(RealtimeEvent.resync, staff), isNull);
    });

    test('customer sentences; their own actions are not announced', () {
      final me = actor('CUSTOMER');
      expect(liveToastText(consent('pending'), me), 'Your insurer sent a POPIA consent form to sign');
      expect(liveToastText(consent('signed'), me), isNull);
      expect(liveToastText(const RealtimeEvent('claim.updated', {'claimId': 'claim_1a2b3c4d9', 'stage': 'Screening'}), me),
          'Your claim moved to Screening · claim 1A2B3C4D');
      expect(liveToastText(const RealtimeEvent('claim.message', {'claimId': 'claim_1a2b3c4d9', 'from': 'insurer'}), me),
          'New message from your insurer · claim 1A2B3C4D');
      expect(liveToastText(const RealtimeEvent('claim.message', {'claimId': 'claim_1a2b3c4d9', 'from': 'customer'}), me), isNull);
      expect(liveToastText(const RealtimeEvent('link.updated', {'requestId': 'plr_1', 'change': 'approved'}), me), 'Your policy link was approved');
    });

    testWidgets('a staff notice shows one SnackBar; the echo of the user\'s own action does not', (tester) async {
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      final live = FakeRealtime(backend);
      await tester.pumpWidget(const EasyClaimApp(initialScreen: Scaffold(body: Text('Queue'))));
      live.connect();
      await tester.pump(const Duration(milliseconds: 50));

      live.push('consent.updated', {'consentId': 'cst_1', 'subjectType': 'claim', 'subjectId': 'claim_1a2b3c4d9', 'status': 'viewed'});
      live.push('consent.updated', {'consentId': 'cst_1', 'subjectType': 'claim', 'subjectId': 'claim_1a2b3c4d9', 'status': 'signed'});
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const Key('live-toast')), findsOneWidget);
      expect(find.text('Customer signed the POPIA mandate · claim 1A2B3C4D'), findsOneWidget);
      expect(find.text('Customer is reading the POPIA mandate · claim 1A2B3C4D'), findsNothing, reason: 'one toast, never stacked');

      // The user just did something (a write): the matching notice is not announced back.
      await _pumpFor(tester, const Duration(seconds: 5));
      expect(find.byKey(const Key('live-toast')), findsNothing);
      ApiClient.lastWriteAt = DateTime.now();
      live.push('claim.updated', {'claimId': 'claim_1a2b3c4d9', 'stage': 'Screening'});
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const Key('live-toast')), findsNothing);

      live.dispose();
      await _pumpFor(tester, const Duration(seconds: 1));
    });
  });
}
