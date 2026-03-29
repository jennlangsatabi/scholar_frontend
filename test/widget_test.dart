import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// This must match the 'name' field in your pubspec.yaml exactly

void main() {
  testWidgets('Initial Load Test', (WidgetTester tester) async {
    // This builds your app's main widget
    await tester.pumpWidget(const MyApp());

    // Basic check to see if the app loads a Material interface
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

class MyApp extends StatelessWidget {

  const MyApp({Key? key}) : super(key: key);



  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      home: Scaffold(

        appBar: AppBar(

          title: const Text('Scholar Flutter'),

        ),

        body: const Center(

          child: Text('Welcome to Scholar Flutter!'),

        ),

      ),

    );

  }

}
