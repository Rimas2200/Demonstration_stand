// import 'package:flutter/material.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:flutter/services.dart' show rootBundle;

// class Model3DViewer extends StatelessWidget {
//   const Model3DViewer({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<String>(
//       future: rootBundle.loadString('assets/html/model.html'),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.done &&
//             snapshot.hasData) {
//           final html = snapshot.data!;

//           return InAppWebView(
//             initialOptions: InAppWebViewGroupOptions(
//               android: AndroidInAppWebViewOptions(useHybridComposition: true),
//               crossPlatform: InAppWebViewOptions(javaScriptEnabled: true),
//             ),
//             initialUrlRequest: URLRequest(url: Uri.parse("about:blank")),
//             initialData: InAppWebViewInitialData(html),
//           );
//         } else if (snapshot.hasError) {
//           return const Text("Ошибка загрузки модели");
//         }
//         return const Center(child: CircularProgressIndicator());
//       },
//     );
//   }
// }
