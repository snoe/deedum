class Feed {
  final String? title;
  final Uri? uri;
  final List<dynamic>? links;
  final String? content;
  final String lastFetchedAt;

  Feed(this.uri, this.title, this.links, this.content, this.lastFetchedAt);

  @override
  String toString() {
    return "Feed<$uri, $title, $links>";
  }
}

class FeedEntry {
  String? entryDate;
  String? entryTitle;
  Uri entryUri;
  String line;
  String feedTitle;

  FeedEntry(this.feedTitle, this.entryUri, this.entryDate, this.entryTitle,
      this.line);
}
