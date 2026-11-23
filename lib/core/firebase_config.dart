import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// Public client identifiers; the service account is stored only on the server.
class FirebaseConfig {
  static const android = FirebaseOptions(
    apiKey: "AIzaSyAXK-47SqevhQwEsDDperXFPR-8j_ONzSw",
    appId: "1:597013810711:android:9bb3cf3581670c7e571652",
    messagingSenderId: "597013810711",
    projectId: "filacero-b94e6",
  );
  static FirebaseOptions? get current =>
      defaultTargetPlatform == TargetPlatform.android ? android : null;
}
