# Ataa release shrinker rules.
#
# Keep this file minimal: the Flutter Gradle plugin adds the engine/embedding
# rules, and every Flutter plugin ships its own consumer rules.

# The Flutter embedding references Play Core deferred-component classes that
# this app does not bundle. They are never reached at runtime.
-dontwarn com.google.android.play.core.**
