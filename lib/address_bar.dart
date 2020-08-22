import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class AddressBar extends StatelessWidget {
  AddressBar({this.controller, this.loading, this.onLocation});
  final TextEditingController controller;
  final loading;
  final onLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(children: [
        Expanded(
            flex: 1,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: loading ? Colors.green[300] : Colors.orange[300],
                    borderRadius: BorderRadius.all(Radius.circular(5))),
                child: Container(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                    margin: EdgeInsets.fromLTRB(0, 5, 0, 5),
                    child: TextField(
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: TextStyle(fontSize: 14),
                        controller: controller,
                        onTap: () => controller.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: controller.value.text.length,
                            ),
                        onSubmitted: (value) {
                          onLocation(Uri.parse(value));
                        })))),
      ]),
    );
  }
}
