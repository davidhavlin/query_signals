import 'package:auto_route/auto_route.dart';
import 'package:example/home/routes/home.route.dart';
import 'package:example/posts/routes/post_detail.route.dart';
import 'package:example/posts/routes/posts.route.dart';
import 'package:example/posts/routes/posts_paginated.route.dart';

final router = RootStackRouter.build(
  defaultRouteType: const RouteType.adaptive(),
  guards: [],
  routes: [
    NamedRouteDef(
      name: 'HomeRoute',
      initial: true,
      path: '/', // optional
      builder: (context, data) {
        return const HomeRoute(title: 'Home');
      },
    ),
    NamedRouteDef(
      name: 'PostsRoute',
      path: '/posts', // optional
      builder: (context, data) {
        return PostsRoute();
      },
    ),
    NamedRouteDef(
      name: 'PostsPaginatedRoute',
      path: '/posts-paginated', // optional
      builder: (context, data) {
        return PostsPaginatedRoute();
      },
    ),
    NamedRouteDef(
      name: 'PostDetailRoute',
      path: '/post-detail/:postId', // optional
      builder: (context, data) {
        return PostDetailRoute(postId: data.params.getString('postId'));
      },
    ),
    // ... other routes
  ],
);
