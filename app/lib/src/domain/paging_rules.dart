/// One page request: [limit] rows starting at the zero-based offset [from].
class PageRequest {
  const PageRequest({required this.from, required this.limit});

  final int from;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is PageRequest && other.from == from && other.limit == limit;

  @override
  int get hashCode => Object.hash(from, limit);

  @override
  String toString() => 'PageRequest($from, $limit)';
}

/// Pure rules for lists that are loaded page by page.
abstract final class PagingRules {
  /// No single request may ask for more rows than this.
  static const maxRowsPerRequest = 200;

  /// How many rows to reload so the rows already on screen stay on screen:
  /// [shown] rounded up to whole pages, and at least one page.
  static int rowsToReload({required int shown, required int pageSize}) {
    final size = _pageSize(pageSize);
    if (shown <= size) return size;
    final pages = (shown + size - 1) ~/ size;
    return pages * size;
  }

  /// The page requests that cover the first [wanted] rows, in order. Each
  /// request asks for at most [pageSize] rows (capped at
  /// [maxRowsPerRequest]).
  static List<PageRequest> pages({required int wanted, required int pageSize}) {
    final size = _pageSize(pageSize);
    final requests = <PageRequest>[];
    for (var from = 0; from < wanted; from += size) {
      final left = wanted - from;
      requests.add(PageRequest(from: from, limit: left < size ? left : size));
    }
    return requests;
  }

  static int _pageSize(int pageSize) {
    if (pageSize < 1) return 1;
    return pageSize > maxRowsPerRequest ? maxRowsPerRequest : pageSize;
  }
}
