import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AddressBar extends StatelessWidget {
  AddressBar({this.controller, this.focusNode, this.loading, this.onLocation});
  final TextEditingController controller;
  final loading;
  final onLocation;
  final focusNode;

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
                        focusNode: focusNode,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        controller: controller,
                        onSubmitted: (value) {
                          var newURL = Uri.parse(value);
                          if (!newURL.hasScheme) {
                            newURL = Uri.parse("gemini://" + value);
                          }
                          onLocation(newURL);
                        })))),
      ]),
    );
  }
}
