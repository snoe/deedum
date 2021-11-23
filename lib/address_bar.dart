import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:deedum/main.dart';
import 'package:string_validator/string_validator.dart' as validator;

class AddressBar extends StatelessWidget {
  const AddressBar({
    Key? key,
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onLocation,
  }) : super(key: key);

  final TextEditingController controller;
  final bool loading;
  final ValueChanged<Uri> onLocation;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: loading ? Colors.green[300] : Colors.orange[300],
                borderRadius: const BorderRadius.all(Radius.circular(5))),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              margin: const EdgeInsets.fromLTRB(0, 5, 0, 5),
              child: TextField(
                keyboardType: TextInputType.url,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
                focusNode: focusNode,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
                controller: controller,
                onSubmitted: (value) async {
                  Uri newURL = Uri.tryParse(value)!;
                  final validated = (newURL.scheme == "gemini" ||
                      newURL.scheme == "about" ||
                      validator.isURL(value, {
                        "protocols": ['gemini'],
                        "require_tld": true,
                        "require_protocol": false,
                        "allow_underscores": true
                      }));
                  if (validated) {
                    if (!newURL.hasScheme) {
                      newURL = Uri.parse("gemini://" + value);
                    }
                  } else {
                    String searchEngine =
                        appKey.currentState!.settings["search"];
                    newURL = Uri.parse(searchEngine);
                    newURL = newURL.replace(query: value);
                  }
                  onLocation(newURL);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
