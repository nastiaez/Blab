import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blab/app/telegram_route.dart';
import 'package:blab/app/router.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('every registered pushed page uses the shared route', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    final audited = <String>[];
    void audit(List<RouteBase> routes, String prefix) {
      for (final route in routes.whereType<GoRoute>()) {
        final path = route.path.startsWith('/')
            ? route.path
            : '$prefix/${route.path}';
        if (route.pageBuilder != null) {
          final state = GoRouterState(
            blabRouter.configuration,
            uri: Uri.parse(
              path.replaceAll(':id', 'chat-1').replaceAll(':token', 'test'),
            ),
            matchedLocation: path,
            fullPath: path,
            pathParameters: const {'id': 'chat-1', 'token': 'test'},
            pageKey: ValueKey(path),
          );
          final page = route.pageBuilder!(context, state);
          if (['/', '/chats', '/profile'].contains(path)) {
            expect(page, isA<NoTransitionPage<void>>(), reason: path);
          } else {
            expect(page, isA<TelegramPage<void>>(), reason: path);
            final created = page.createRoute(context);
            expect(created, isA<PageRouteBuilder<void>>(), reason: path);
            expect(
              (created as PageRouteBuilder<void>).transitionDuration,
              const Duration(milliseconds: 150),
            );
            expect(
              created.reverseTransitionDuration,
              const Duration(milliseconds: 150),
            );
            audited.add(path);
          }
        } else {
          expect(
            route.redirect,
            isNotNull,
            reason: 'No transition bypass: $path',
          );
        }
        audit(route.routes, path == '/' ? '' : path);
      }
    }

    audit(blabRouter.configuration.routes, '');
    expect(
      audited,
      containsAll([
        '/chats/new',
        '/chat',
        '/chat/:id',
        '/profile/known-languages',
        '/profile/translation-language',
        '/profile/interface-language',
        '/profile/translation-preferences',
        '/profile/edit',
        '/profile/email',
        '/profile/password',
        '/profile/privacy',
        '/profile/notifications',
        '/profile/delete-account',
      ]),
    );
  });

  testWidgets('reduced motion shows the destination without slide or fade', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    const destination = Key('reduced');
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(),
      ),
    );
    nav.currentState!.push(
      telegramRoute<void>(const Scaffold(key: destination)),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.getTopLeft(find.byKey(destination)).dx, 0);
    expect(
      find.ancestor(
        of: find.byKey(destination),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });

  for (final width in [360.0, 720.0]) {
    testWidgets('fixed travel and stationary background at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final nav = GlobalKey<NavigatorState>();
      const background = Key('background');
      const foreground = Key('foreground');
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(key: background),
        ),
      );
      final origin = tester.getTopLeft(find.byKey(background));
      final route = telegramRoute<void>(const Scaffold(key: foreground));
      nav.currentState!.push(route);
      await tester.pump();
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(foreground, skipOffstage: false)).dx,
        48,
      );
      await tester.pump(const Duration(milliseconds: 75));
      expect(
        tester.getTopLeft(find.byKey(foreground, skipOffstage: false)).dx,
        closeTo(6, .01),
      );
      expect(tester.getTopLeft(find.byKey(background)), origin);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byKey(foreground, skipOffstage: false),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        closeTo(.875, .001),
      );
      await tester.pump(const Duration(milliseconds: 75));
      expect(
        tester.getTopLeft(find.byKey(foreground, skipOffstage: false)).dx,
        0,
      );
      nav.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(
        tester.getTopLeft(find.byKey(foreground, skipOffstage: false)).dx,
        closeTo(6, .01),
      );
      expect(tester.getTopLeft(find.byKey(background)), origin);
      await tester.pumpAndSettle();
      expect(find.byKey(foreground, skipOffstage: false), findsNothing);
    });
  }
}
