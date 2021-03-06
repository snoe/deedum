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

  GemItem(this.url,
      {this.title,
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
      this.onFeed});

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Card(
            shape: this.selected
                ? RoundedRectangleBorder(
                    side: BorderSide(
                        color: Theme.of(context).hintColor, width: 2),
                    borderRadius: BorderRadius.circular(5))
                : null,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 10),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.description),
                    Expanded(
                        flex: 1,
                        child: ListTile(
                          contentPadding: EdgeInsets.only(left: 20),
                          onTap: this.onSelect,
                          subtitle: this.title,
                          title: Text(this.url, style: TextStyle(fontSize: 14)),
                        )),
                    this.showFeed
                        ? IconButton(
                            icon: Icon(
                                this.feedActive
                                    ? Icons.rss_feed
                                    : Icons.rss_feed_outlined,
                                color: this.feedActive
                                    ? Colors.orange
                                    : Colors.black12),
                            onPressed: this.onFeed)
                        : Container(),
                    this.showBookmarked
                        ? IconButton(
                            icon: Icon(
                                this.bookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: bookmarked ? Colors.orange : null),
                            onPressed: this.onBookmark,
                          )
                        : Container(),
                    this.showDelete
                        ? IconButton(
                            icon: Icon(Icons.delete),
                            onPressed:
                                this.disableDelete ? null : this.onDelete,
                          )
                        : Container(),
                  ]),
            )));
  }
}
