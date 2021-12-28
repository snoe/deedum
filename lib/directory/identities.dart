import 'package:deedum/browser_tab/client_cert.dart';
import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/directory/gem_item.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Identities extends DirectoryElement {
  final List<Identity> identities;
  final bookmarkKey = GlobalObjectKey(DateTime.now().millisecondsSinceEpoch);
  final void Function(Identity, Uri) onIdentity;
  final void Function(String, {Uri? uri}) createIdentity;

  Identities({
    Key? key,
    required this.identities,
    required this.onIdentity,
    required this.createIdentity,
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
  Widget build(BuildContext context) {
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
                      return ClientCertAddAlert(createIdentity: createIdentity);
                    });
              },
              leading: const Icon(Icons.explore, color: Colors.white),
              title: const Text("No Identities",
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text("Go forth, explore",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          for (final identity in identities)
            GemItem(
              title: Column(children: [
                for (var page in identity.pages)
                  ListTile(
                    title: Text(page),
                    trailing: const Icon(Icons.delete),
                    onTap: () {
                      onIdentity(identity, Uri.parse(page));
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
