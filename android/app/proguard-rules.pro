# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Hive
-keep class com.hive.** { *; }
-keep class * extends com.hive.**

# Timezone
-keep class com.github.** { *; }

# Your app's classes
-keep class com.example.indayreminder.** { *; }

# Keep serialization methods
-keepclassmembers class * implements com.hive.** {
    public *** read(com.hive.**);
    public void write(com.hive.**, ***);
}

# Keep all model classes that might be serialized
-keepclassmembers class * {
    @com.hive.HiveType *;
}

# Keep all enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep any custom adapters
-keep class * extends com.hive.** {
    public <init>();
}

# Keep notification related classes
-keep class androidx.core.app.** { *; }
-keep class androidx.work.** { *; }