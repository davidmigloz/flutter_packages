// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router/src/state.dart';

import 'test_helpers.dart';

void main() {
  group('GoRouterState from context', () {
    testWidgets('works in builder', (WidgetTester tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, _) {
            final GoRouterState state = GoRouterState.of(context);
            return Text('/ ${state.uri.queryParameters['p']}');
          },
        ),
        GoRoute(
          path: '/a',
          builder: (BuildContext context, _) {
            final GoRouterState state = GoRouterState.of(context);
            return Text('/a ${state.uri.queryParameters['p']}');
          },
        ),
      ];
      final GoRouter router = await createRouter(routes, tester);
      router.go('/?p=123');
      await tester.pumpAndSettle();
      expect(find.text('/ 123'), findsOneWidget);

      router.go('/a?p=456');
      await tester.pumpAndSettle();
      expect(find.text('/a 456'), findsOneWidget);
    });

    testWidgets('works in subtree', (WidgetTester tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) {
            return Builder(
              builder: (BuildContext context) {
                return Text('1 ${GoRouterState.of(context).uri.path}');
              },
            );
          },
          routes: <GoRoute>[
            GoRoute(
              path: 'a',
              builder: (_, _) {
                return Builder(
                  builder: (BuildContext context) {
                    return Text('2 ${GoRouterState.of(context).uri.path}');
                  },
                );
              },
            ),
          ],
        ),
      ];
      final GoRouter router = await createRouter(routes, tester);
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('1 /'), findsOneWidget);

      router.go('/a');
      await tester.pumpAndSettle();
      expect(find.text('2 /a'), findsOneWidget);
      // The query parameter is removed, so is the location in first page.
      expect(find.text('1 /a', skipOffstage: false), findsOneWidget);
    });

    testWidgets('path parameter persists after page is popped', (WidgetTester tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) {
            return Builder(
              builder: (BuildContext context) {
                return Text('1 ${GoRouterState.of(context).uri.path}');
              },
            );
          },
          routes: <GoRoute>[
            GoRoute(
              path: ':id',
              builder: (_, _) {
                return Builder(
                  builder: (BuildContext context) {
                    return Text('2 ${GoRouterState.of(context).pathParameters['id']}');
                  },
                );
              },
            ),
          ],
        ),
      ];
      final GoRouter router = await createRouter(routes, tester);
      await tester.pumpAndSettle();
      expect(find.text('1 /'), findsOneWidget);

      router.go('/123');
      await tester.pumpAndSettle();
      expect(find.text('2 123'), findsOneWidget);
      router.pop();
      await tester.pump();
      // Page 2 is in popping animation but should still be on screen with the
      // correct path parameter.
      expect(find.text('2 123'), findsOneWidget);
    });

    testWidgets('registry retains GoRouterState for exiting route', (WidgetTester tester) async {
      final key = UniqueKey();
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) {
            return Builder(
              builder: (BuildContext context) {
                return Text(GoRouterState.of(context).uri.path);
              },
            );
          },
          routes: <GoRoute>[
            GoRoute(
              path: 'a',
              builder: (_, _) {
                return Builder(
                  builder: (BuildContext context) {
                    return Text(key: key, GoRouterState.of(context).uri.path);
                  },
                );
              },
            ),
          ],
        ),
      ];
      final GoRouter router = await createRouter(routes, tester, initialLocation: '/a');
      expect(tester.widget<Text>(find.byKey(key)).data, '/a');
      final GoRouterStateRegistry registry = tester
          .widget<GoRouterStateRegistryScope>(find.byType(GoRouterStateRegistryScope))
          .notifier!;
      expect(registry.registry.length, 2);
      router.go('/');
      await tester.pump();
      expect(registry.registry.length, 2);
      // should retain the same location even if the location has changed.
      expect(tester.widget<Text>(find.byKey(key)).data, '/a');

      // Finish the pop animation.
      await tester.pumpAndSettle();
      expect(registry.registry.length, 1);
      expect(find.byKey(key), findsNothing);
    });

    testWidgets('imperative pop clears out registry', (WidgetTester tester) async {
      final key = UniqueKey();
      final nav = GlobalKey<NavigatorState>();
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) {
            return Builder(
              builder: (BuildContext context) {
                return Text(GoRouterState.of(context).uri.path);
              },
            );
          },
          routes: <GoRoute>[
            GoRoute(
              path: 'a',
              builder: (_, _) {
                return Builder(
                  builder: (BuildContext context) {
                    return Text(key: key, GoRouterState.of(context).uri.path);
                  },
                );
              },
            ),
          ],
        ),
      ];
      await createRouter(routes, tester, initialLocation: '/a', navigatorKey: nav);
      expect(tester.widget<Text>(find.byKey(key)).data, '/a');
      final GoRouterStateRegistry registry = tester
          .widget<GoRouterStateRegistryScope>(find.byType(GoRouterStateRegistryScope))
          .notifier!;
      expect(registry.registry.length, 2);
      nav.currentState!.pop();
      await tester.pump();
      expect(registry.registry.length, 2);
      // should retain the same location even if the location has changed.
      expect(tester.widget<Text>(find.byKey(key)).data, '/a');

      // Finish the pop animation.
      await tester.pumpAndSettle();
      expect(registry.registry.length, 1);
      expect(find.byKey(key), findsNothing);
    });

    testWidgets('GoRouterState look up should be resilient when there is a nested navigator.', (
      WidgetTester tester,
    ) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) {
            return Scaffold(
              appBar: AppBar(),
              body: Navigator(
                pages: <Page<void>>[
                  MaterialPage<void>(
                    child: Builder(
                      builder: (BuildContext context) {
                        return Center(child: Text(GoRouterState.of(context).uri.toString()));
                      },
                    ),
                  ),
                ],
                onPopPage: (Route<Object?> route, Object? result) {
                  throw UnimplementedError();
                },
              ),
            );
          },
        ),
      ];
      await createRouter(routes, tester);
      expect(find.text('/'), findsOneWidget);
    });

    testWidgets('GoRouterState topRoute accessible from StatefulShellRoute', (
      WidgetTester tester,
    ) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final shellNavigatorKey = GlobalKey<NavigatorState>();
      final routes = <RouteBase>[
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (BuildContext context, GoRouterState state, Widget child) {
            return Scaffold(
              body: Column(
                children: <Widget>[
                  const Text('Screen 0'),
                  Expanded(child: child),
                ],
              ),
            );
          },
          routes: <RouteBase>[
            GoRoute(
              name: 'root',
              path: '/',
              builder: (BuildContext context, GoRouterState state) {
                return const Scaffold(body: Text('Screen 1'));
              },
              routes: <RouteBase>[
                StatefulShellRoute.indexedStack(
                  parentNavigatorKey: rootNavigatorKey,
                  builder:
                      (
                        BuildContext context,
                        GoRouterState state,
                        StatefulNavigationShell navigationShell,
                      ) {
                        final String? routeName = GoRouterState.of(context).topRoute?.name;
                        final String title = switch (routeName) {
                          'a' => 'A',
                          'b' => 'B',
                          _ => 'Unknown',
                        };
                        return Column(
                          children: <Widget>[
                            Text(title),
                            Expanded(child: navigationShell),
                          ],
                        );
                      },
                  branches: <StatefulShellBranch>[
                    StatefulShellBranch(
                      routes: <RouteBase>[
                        GoRoute(
                          name: 'a',
                          path: 'a',
                          builder: (BuildContext context, GoRouterState state) {
                            return const Scaffold(body: Text('Screen 2'));
                          },
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      routes: <RouteBase>[
                        GoRoute(
                          name: 'b',
                          path: 'b',
                          builder: (BuildContext context, GoRouterState state) {
                            return const Scaffold(body: Text('Screen 2'));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];
      final GoRouter router = await createRouter(
        routes,
        tester,
        initialLocation: '/a',
        navigatorKey: rootNavigatorKey,
      );
      expect(find.text('A'), findsOneWidget);

      router.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('GoRouterState.fullPath', () {
    final states = <String, GoRouterState>{};

    setUp(states.clear);

    // Names the page like apps commonly do, so observers can read it back.
    GoRouterPageBuilder capturePage(String label) {
      return (BuildContext context, GoRouterState state) {
        states[label] = state;
        return MaterialPage<void>(
          key: state.pageKey,
          name: state.name ?? state.fullPath,
          child: Text(label),
        );
      };
    }

    List<RouteBase> familyRoutes() => <RouteBase>[
      GoRoute(
        path: '/family/:fid',
        pageBuilder: capturePage('family'),
        routes: <RouteBase>[GoRoute(path: 'person/:pid', pageBuilder: capturePage('person'))],
      ),
    ];

    testWidgets('a parent route keeps its own full path when a child is opened with go', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await createRouter(
        familyRoutes(),
        tester,
        initialLocation: '/family/f2',
      );
      expect(states['family']!.fullPath, '/family/:fid');

      router.go('/family/f2/person/p1');
      await tester.pumpAndSettle();

      expect(states['family']!.fullPath, '/family/:fid');
      expect(states['family']!.matchedLocation, '/family/f2');
      expect(states['person']!.fullPath, '/family/:fid/person/:pid');
      expect(states['person']!.matchedLocation, '/family/f2/person/p1');
      expect(router.state.fullPath, '/family/:fid/person/:pid');
    });

    testWidgets('a parent route under a ShellRoute keeps its own full path', (
      WidgetTester tester,
    ) async {
      final routes = <RouteBase>[
        ShellRoute(
          pageBuilder: (BuildContext context, GoRouterState state, Widget child) {
            states['shell'] = state;
            return MaterialPage<void>(key: state.pageKey, child: child);
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/a',
              pageBuilder: capturePage('a'),
              routes: <RouteBase>[GoRoute(path: 'b/:id', pageBuilder: capturePage('b'))],
            ),
          ],
        ),
      ];
      final GoRouter router = await createRouter(routes, tester, initialLocation: '/a');

      router.go('/a/b/1');
      await tester.pumpAndSettle();

      expect(states['a']!.fullPath, '/a');
      expect(states['b']!.fullPath, '/a/b/:id');
      // A shell wraps its current child, so it keeps carrying the child's path.
      expect(states['shell']!.fullPath, '/a/b/:id');
      expect(router.state.fullPath, '/a/b/:id');
    });

    testWidgets('a pushed page and the page beneath it keep their own full path', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await createRouter(
        familyRoutes(),
        tester,
        initialLocation: '/family/f2',
      );

      router.push('/family/f2/person/p1');
      await tester.pumpAndSettle();

      expect(states['family']!.fullPath, '/family/:fid');
      expect(states['person']!.fullPath, '/family/:fid/person/:pid');
      expect(router.state.fullPath, '/family/:fid/person/:pid');
    });

    testWidgets('a page named after its fullPath identifies the parent revealed by a pop', (
      WidgetTester tester,
    ) async {
      final observer = _PopObserver();
      final GoRouter router = await createRouter(
        familyRoutes(),
        tester,
        initialLocation: '/family/f2',
        observers: <NavigatorObserver>[observer],
      );

      router.go('/family/f2/person/p1');
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();

      expect(observer.revealedNames, <String?>['/family/:fid']);
    });

    testWidgets('top-level onEnter keeps receiving the whole matched path', (
      WidgetTester tester,
    ) async {
      final onEnterPaths = <(String?, String?)>[];
      final router = GoRouter(
        onEnter:
            (BuildContext context, GoRouterState current, GoRouterState next, GoRouter goRouter) {
              onEnterPaths.add((current.fullPath, next.fullPath));
              return const Allow();
            },
        routes: <RouteBase>[
          GoRoute(path: '/', builder: dummy),
          ...familyRoutes(),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      onEnterPaths.clear();

      router.go('/family/f2/person/p1');
      await tester.pumpAndSettle();
      router.go('/family/f2');
      await tester.pumpAndSettle();

      expect(onEnterPaths, <(String?, String?)>[
        ('/', '/family/:fid/person/:pid'),
        ('/family/:fid/person/:pid', '/family/:fid'),
      ]);
    });

    testWidgets('a child outside its ShellRoute navigator keeps the path through the shell', (
      WidgetTester tester,
    ) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final routes = <RouteBase>[
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) => child,
          routes: <RouteBase>[
            GoRoute(
              path: '/a',
              pageBuilder: capturePage('a'),
              routes: <RouteBase>[
                GoRoute(
                  path: 'b/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: capturePage('b'),
                ),
              ],
            ),
          ],
        ),
      ];
      final GoRouter router = await createRouter(
        routes,
        tester,
        initialLocation: '/a',
        navigatorKey: rootNavigatorKey,
      );

      router.go('/a/b/1');
      await tester.pumpAndSettle();

      expect(states['a']!.fullPath, '/a');
      expect(states['b']!.fullPath, '/a/b/:id');
      expect(router.state.fullPath, '/a/b/:id');
    });

    testWidgets('a route inside a ShellRoute below a parent route keeps the path above the shell', (
      WidgetTester tester,
    ) async {
      final routes = <RouteBase>[
        GoRoute(
          path: '/x',
          pageBuilder: capturePage('x'),
          routes: <RouteBase>[
            ShellRoute(
              builder: (BuildContext context, GoRouterState state, Widget child) => child,
              routes: <RouteBase>[
                GoRoute(
                  path: 'a',
                  pageBuilder: capturePage('a'),
                  routes: <RouteBase>[GoRoute(path: 'b/:id', pageBuilder: capturePage('b'))],
                ),
              ],
            ),
          ],
        ),
      ];
      final GoRouter router = await createRouter(routes, tester, initialLocation: '/x/a');

      router.go('/x/a/b/1');
      await tester.pumpAndSettle();

      expect(states['x']!.fullPath, '/x');
      expect(states['a']!.fullPath, '/x/a');
      expect(states['b']!.fullPath, '/x/a/b/:id');
    });

    testWidgets('the route-level redirect of a parent route gets its own full path', (
      WidgetTester tester,
    ) async {
      final redirectStates = <String, GoRouterState>{};
      final routes = <RouteBase>[
        GoRoute(
          path: '/family/:fid',
          builder: dummy,
          redirect: (BuildContext context, GoRouterState state) {
            redirectStates['family'] = state;
            return null;
          },
          routes: <RouteBase>[
            GoRoute(
              path: 'person/:pid',
              builder: dummy,
              redirect: (BuildContext context, GoRouterState state) {
                redirectStates['person'] = state;
                return null;
              },
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/family/f2/person/p1');

      expect(redirectStates['family']!.fullPath, '/family/:fid');
      expect(redirectStates['family']!.matchedLocation, '/family/f2');
      expect(redirectStates['person']!.fullPath, '/family/:fid/person/:pid');
    });

    testWidgets('the onExit of a parent route gets its own full path', (WidgetTester tester) async {
      final exitStates = <String, GoRouterState>{};
      final routes = <RouteBase>[
        GoRoute(path: '/', builder: dummy),
        GoRoute(
          path: '/family/:fid',
          builder: dummy,
          onExit: (BuildContext context, GoRouterState state) {
            exitStates['family'] = state;
            return true;
          },
          routes: <RouteBase>[
            GoRoute(
              path: 'person/:pid',
              builder: dummy,
              onExit: (BuildContext context, GoRouterState state) {
                exitStates['person'] = state;
                return true;
              },
            ),
          ],
        ),
      ];
      final GoRouter router = await createRouter(
        routes,
        tester,
        initialLocation: '/family/f2/person/p1',
      );

      router.go('/');
      await tester.pumpAndSettle();

      expect(exitStates['family']!.fullPath, '/family/:fid');
      expect(exitStates['family']!.matchedLocation, '/family/f2');
      expect(exitStates['person']!.fullPath, '/family/:fid/person/:pid');
    });
  });
}

/// Records the name of the route revealed by each pop.
class _PopObserver extends NavigatorObserver {
  final List<String?> revealedNames = <String?>[];

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    revealedNames.add(previousRoute?.settings.name);
  }
}
