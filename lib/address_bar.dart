import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:string_validator/string_validator.dart' as validator;

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
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
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
                        onSubmitted: (value) async {
                          Uri newURL;
                          if (validator.isURL(value, {
                                "protocols": ['gemini'],
                                "require_tld": true,
                                "require_protocol": false,
                                "allow_underscores": true
                              }) ||
                              validator.isURL(value, {
                                "protocols": ['gemini'],
                                "require_tld": false,
                                "require_protocol": true,
                                "allow_underscores": true
                              })) {
                            newURL = Uri.tryParse(value);
                            if (!newURL.hasScheme) {
                              newURL = Uri.parse("gemini://" + value);
                            }
                          } else {
                            String searchEngine =
                                (await SharedPreferences.getInstance())
                                    .getString("search");
                            newURL = Uri.parse(searchEngine);
                            newURL = newURL.replace(query: value);
                          }

                          onLocation(newURL);
                        })))),
      ]),
    );
  }
}
