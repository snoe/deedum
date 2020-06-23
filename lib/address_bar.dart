
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class AddressBar extends StatelessWidget {
  AddressBar({this.controller, this.loading, this.onLocation});
  final TextEditingController controller;
  final loading;
  final onLocation;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          flex: 1,
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: loading ? Colors.purple : Colors.white, borderRadius: BorderRadius.all(Radius.circular(5))),
              child: Padding(
                  padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
                  child: TextField(
                    decoration: InputDecoration(border:InputBorder.none),
                    style: TextStyle(fontSize: 14),
                      controller: controller,
                      onSubmitted: (value) {
                        onLocation(Uri.parse(value));
                      })))),
    ]);
  }
}
