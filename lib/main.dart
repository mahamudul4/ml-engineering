import 'package:flutter/material.dart';

import 'data/learning_repository.dart';
import 'state/learning_controller.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repository = await LearningRepository.open();
    final controller = LearningController(repository);
    await controller.load();
    runApp(LearningApp(controller: controller));
  } catch (_) {
    runApp(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_rounded, size: 48, color: forest),
                  const SizedBox(height: 20),
                  const Text(
                    'Your learning space could not open.',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Restart the app to retry. Your saved data has not been cleared.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: main, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LearningApp extends StatelessWidget {
  final LearningController controller;
  const LearningApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'ML Path',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: controller.themeMode,
      home: LearningShell(controller: controller),
    ),
  );
}
