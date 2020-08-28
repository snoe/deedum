import 'package:flutter/material.dart';

class Directory extends StatefulWidget {
  final children;
  final icons;

  Directory({this.children, this.icons});

  @override
  _DirectoryState createState() => _DirectoryState(this.children, this.icons);
}

class _DirectoryState extends State<Directory>
    with SingleTickerProviderStateMixin {
  final controllerKey = GlobalObjectKey("tabcontroller");
  final children;
  final icons;

  TabController _tabController;
  int _activeTabIndex = 0;

  _DirectoryState(this.children, this.icons);

  @override
  void initState() {
    super.initState();
    _tabController = new TabController(vsync: this, length: children.length);

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
            style: TextStyle(fontSize: 5.5, fontFamily: "DejaVu Sans Mono")),
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
