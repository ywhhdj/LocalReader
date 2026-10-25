# Add your ProGuard rules here

# ---------- Room ----------
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.room.paging.**
-keepclassmembers class * { @androidx.room.* <methods>; }

# ---------- junrar（CBR / RAR 解压） ----------
-keep class com.github.junrar.** { *; }
-dontwarn com.github.junrar.**
