import 'package:deedum/models/tab.dart';

class TabState {
  int tabIndex = -1;
  Map<int, Tab> tabs = {};
  List<int> tabOrder = [];

  void add(int ident, Tab tab) {
    tabs[ident] = tab;
    tabOrder.add(ident);
  }

  void removeIndex(int dropIndex) {
    var ident = tabOrder[dropIndex];
    tabOrder.removeAt(dropIndex);
    tabs.remove(ident);
    if (tabIndex == dropIndex) {
      tabIndex = 0;
    } else if (tabIndex > dropIndex) {
      tabIndex -= 1;
    }
  }

  Tab? fromIndex(int index) {
    if (tabs.isNotEmpty) {
      return tabs[tabOrder[index]]!;
    }
  }

  Tab? current() {
    if (tabIndex >= 0) {
      return fromIndex(tabIndex);
    }
  }
}
