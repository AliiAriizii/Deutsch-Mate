# Flutter's own engine classes are referenced reflectively from native code.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_tts talks to the platform TTS engine through reflection.
-keep class com.tundralabs.fluttertts.** { *; }

# Keep annotations that AndroidX relies on at runtime.
-keepattributes *Annotation*, Signature, InnerClasses

# Line numbers make Play Console crash reports readable; the source file name
# is renamed so it does not leak the original paths.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Flutter's engine references Play Core's split-install API for deferred
# components. This app does not use deferred components, so the Play Core
# library is not on the classpath and R8 fails the build on the dangling
# references. Suppressing the warning is the documented fix - adding the
# dependency instead would ship a library for a feature we do not use.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
