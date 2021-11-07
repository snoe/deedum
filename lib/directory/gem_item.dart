import 'package:flutter/material.dart';

class GemItem extends StatelessWidget {
  final String url;
  final Widget title;
  final bool bookmarked;
  final bool feedActive;
  final bool selected;
  final bool showTitle;
  final bool showBookmarked;
  final bool showDelete;
  final bool disableDelete;

  final bool showFeed;

  final Function onSelect;
  final Function onBookmark;
  final Function onDelete;
  final Function onFeed;

  const GemItem({
    Key key,
    this.url,
    this.title,
    this.selected = false,
    this.bookmarked = false,
    this.feedActive = false,
    this.showTitle = true,
    this.showBookmarked = false,
    this.showDelete = false,
    this.disableDelete = false,
    this.showFeed = false,
    this.onSelect,
    this.onBookmark,
    this.onDelete,
    this.onFeed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: selected
          ? RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).hintColor, width: 2),
              borderRadius: BorderRadius.circular(5))
          : null,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 10),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.description),
              Expanded(
                  flex: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(left: 20),
                    onTap: onSelect,
                    subtitle: title,
                    title: Text(url, style: const TextStyle(fontSize: 14)),
                  )),
              showFeed
                  ? IconButton(
                      icon: Icon(
                          feedActive ? Icons.rss_feed : Icons.rss_feed_outlined,
                          color: feedActive ? Colors.orange : Colors.black12),
                      onPressed: onFeed)
                  : Container(),
              showBookmarked
                  ? IconButton(
                      icon: Icon(
                          bookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: bookmarked ? Colors.orange : null),
                      onPressed: onBookmark,
                    )
                  : Container(),
              showDelete
                  ? IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: disableDelete ? null : onDelete,
                    )
                  : Container(),
            ]),
      ),
    );
  }
}
