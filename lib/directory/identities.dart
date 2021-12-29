import 'package:deedum/app_state.dart';
import 'package:deedum/browser_tab/client_cert.dart';
import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/directory/gem_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Identities extends DirectoryElement {
  const Identities({
    Key? key,
  }) : super(key: key);

  @override
  String get title => [
        "██╗██████╗ ███████╗███╗   ██╗████████╗██╗████████╗██╗███████╗███████╗",
        "██║██╔══██╗██╔════╝████╗  ██║╚══██╔══╝██║╚══██╔══╝██║██╔════╝██╔════╝",
        "██║██║  ██║█████╗  ██╔██╗ ██║   ██║   ██║   ██║   ██║█████╗  ███████╗",
        "██║██║  ██║██╔══╝  ██║╚██╗██║   ██║   ██║   ██║   ██║██╔══╝  ╚════██║",
        "██║██████╔╝███████╗██║ ╚████║   ██║   ██║   ██║   ██║███████╗███████║",
        "╚═╝╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝   ╚═╝   ╚═╝╚══════╝╚══════╝",
      ].join("\n");

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            color: Colors.black12,
            child: ListTile(
              onTap: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return ClientCertAddAlert(
                          createIdentity: appState.createIdentity);
                    });
              },
              leading: const Icon(Icons.explore, color: Colors.white),
              title: const Text("No Identities",
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text("Go forth, explore",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          for (final identity in appState.identities)
            GemItem(
              title: Column(children: [
                for (var page in identity.pages)
                  ListTile(
                    title: Text(page),
                    trailing: const Icon(Icons.delete),
                    onTap: () {
                      appState.onIdentity(identity, Uri.parse(page));
                    },
                  )
              ]),
              url: identity.name,
              onSelect: () {},
            ),
        ],
      ),
    );
  }
}
