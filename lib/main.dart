import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rov_coach/app.dart';
import 'package:rov_coach/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: kIsWeb
        ? DefaultFirebaseOptions.currentPlatform
        : DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();

  runApp(
    const ProviderScope(
      child: RovCoachApp(),
    ),
  );
}

