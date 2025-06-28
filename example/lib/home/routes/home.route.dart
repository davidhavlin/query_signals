import 'package:example/shared/router/router.dart';
import 'package:flutter/material.dart';

class HomeRoute extends StatefulWidget {
  const HomeRoute({super.key, required this.title});

  final String title;

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // buttons
          ElevatedButton(
            onPressed: () {
              router.pushPath('/posts');
            },
            child: const Text('Posts'),
          ),
          ElevatedButton(
            onPressed: () {
              router.pushPath('/posts-paginated');
            },
            child: const Text('Posts Test with query'),
          ),
        ],
      ),
    );
  }
}
