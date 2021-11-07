import 'package:deedum/directory/directory_element.dart';
import 'package:flutter/material.dart';

class Directory extends StatefulWidget {
  final List<DirectoryElement> children;
  final List<IconData> icons;

  const Directory({
    Key key,
    @required this.children,
    @required this.icons,
  }) : super(key: key);

  @override
  _DirectoryState createState() => _DirectoryState();
}

class _DirectoryState extends State<Directory>
    with SingleTickerProviderStateMixin {
  final controllerKey = const GlobalObjectKey("tabcontroller");

  TabController _tabController;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: widget.children.length);

    _tabController.addListener(_setActiveTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setActiveTabIndex() {
    setState(() {
      _activeTabIndex = _tabController.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    var title = widget.children[_activeTabIndex].title;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.orange,
        centerTitle: true,
        title: Text(title,
            style:
                const TextStyle(fontSize: 5.5, fontFamily: "DejaVu Sans Mono")),
        bottom: TabBar(
          controller: _tabController,
          tabs: widget.icons.map<Widget>((i) => Tab(icon: Icon(i))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: widget.children,
      ),
    );
  }
}
