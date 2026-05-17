# =============================================================================
# Tympeak — ProGuard / R8 rules
# Shrinking + resource shrinking ON, obfuscation OFF (open-source friendly).
# =============================================================================

# Keep source line numbers and original names — easier crash reading + license-friendly.
-dontobfuscate
-keepattributes SourceFile,LineNumberTable,*Annotation*,InnerClasses,EnclosingMethod

# -----------------------------------------------------------------------------
# Flutter engine + embedding
# -----------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Keep the host activity reachable from the Android side.
-keep class com.spacechase.tympeak.** { *; }

# -----------------------------------------------------------------------------
# flutter_local_notifications — needs Gson for scheduled-notification persistence
# https://pub.dev/packages/flutter_local_notifications#release-build-configuration
# -----------------------------------------------------------------------------
-keep class com.dexterous.** { *; }

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keepattributes Signature

# -----------------------------------------------------------------------------
# androidx core library desugaring (java.time, etc.)
# -----------------------------------------------------------------------------
-dontwarn java.lang.invoke.StringConcatFactory

# -----------------------------------------------------------------------------
# Kotlin metadata, suppress unused warnings
# -----------------------------------------------------------------------------
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations,RuntimeInvisibleParameterAnnotations

# Don't fail the build on missing classes from optional native deps.
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
