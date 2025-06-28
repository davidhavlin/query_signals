import 'package:example/posts/components/post_card.dart';
import 'package:example/posts/models/posts_page.model.dart';
import 'package:example/shared/service/api.service.dart';
import 'package:flutter/material.dart';
import 'package:persist_signals/testquery/mixins/query_mixin.dart';
import 'package:signals/signals_flutter.dart';

class PostsPaginatedRoute extends StatefulWidget {
  const PostsPaginatedRoute({super.key});

  @override
  State<PostsPaginatedRoute> createState() => _PostsPaginatedRouteState();
}

class _PostsPaginatedRouteState extends State<PostsPaginatedRoute>
    with SimpleQueryMixin {
  static const int pageSize = 20;

  final ScrollController _scrollController = ScrollController();

  // React Query-style infinite query
  late final postsInfinite =
      infiniteQuery<PostsPage, Map<String, dynamic>, int>(
        key: ['posts-infinite'],
        fetch: (pageParam) async {
          final skip = pageParam * pageSize;
          print('Fetching page: skip=$skip, limit=$pageSize');
          return await api.$get('posts?limit=$pageSize&skip=$skip');
        },
        transform: (json) => PostsPage.fromJson(json),
        getNextPageParam: (lastPage, allPages) {
          // Return next page number if there are more posts, null otherwise
          return lastPage.hasMore ? allPages.length : null;
        },
        initialPageParam: 0,
        staleDuration: Duration(minutes: 5),
        cacheDuration: Duration(minutes: 30),
      );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      postsInfinite.fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Infinite Query Posts'),
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade800,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => postsInfinite.refetch(),
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh All',
          ),
        ],
      ),
      body: Watch((context) {
        // Handle initial loading
        if (postsInfinite.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading posts...',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        // Handle initial error
        if (postsInfinite.isError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load posts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    postsInfinite.error?.message ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => postsInfinite.refetch(),
                    icon: Icon(Icons.refresh),
                    label: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Get all posts from all pages
        final allPosts =
            postsInfinite.data?.flatMap((page) => page.posts) ?? [];
        final totalPosts = postsInfinite.data?.pages.isNotEmpty == true
            ? postsInfinite.data!.pages.first.total
            : 0;

        return Column(
          children: [
            // Stats bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
              ),
              child: Row(
                children: [
                  Icon(Icons.article, size: 20, color: Colors.blue.shade600),
                  SizedBox(width: 8),
                  Text(
                    'Loaded: ${allPosts.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  if (totalPosts > 0) ...[
                    Text(
                      ' of $totalPosts total',
                      style: TextStyle(color: Colors.blue.shade600),
                    ),
                  ],
                  SizedBox(width: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${postsInfinite.data?.pages.length ?? 0} pages',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Spacer(),
                  if (postsInfinite.isStale) ...[
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Colors.orange.shade600,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Stale',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => postsInfinite.sync(),
                    icon: Icon(Icons.sync, size: 16),
                    label: Text('Sync'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                      side: BorderSide(color: Colors.blue.shade300),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: Size(0, 32),
                    ),
                  ),
                ],
              ),
            ),

            // Posts list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => postsInfinite.refetch(),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount:
                      allPosts.length + (postsInfinite.hasNextPage ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Regular post item
                    if (index < allPosts.length) {
                      return PostCard(post: allPosts[index]);
                    }

                    // Loading indicator at bottom
                    return Container(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          if (postsInfinite.isFetchingNextPage) ...[
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Loading more posts...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ] else if (!postsInfinite.hasNextPage) ...[
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade400,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'All posts loaded!',
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ] else ...[
                            // Fetch next page when this is visible
                            OutlinedButton.icon(
                              onPressed: () => postsInfinite.fetchNextPage(),
                              icon: Icon(Icons.expand_more),
                              label: Text('Load More'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue.shade600,
                                side: BorderSide(color: Colors.blue.shade300),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
