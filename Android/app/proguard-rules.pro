# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Preserve line numbers for readable Crashlytics stack traces, then hide
# the original source file name.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# --- Room e WorkManager -------------------------------------------------
# La 1.2 pubblicata moriva all'avvio, su Android 16, prima di mostrare
# qualunque schermata:
#
#   Unable to get provider androidx.startup.InitializationProvider
#   Caused by: Failed to create an instance of androidx.work.impl.WorkDatabase
#
# WorkManager non lo usiamo noi: arriva di rimbalzo da Firebase e da Play
# Services Ads, e androidx.startup lo inizializza all'avvio del processo. Room
# istanzia la classe generata <NomeDatabase>_Impl cercandola PER NOME a runtime,
# quindi se R8 la rinomina o la elimina il risultato e' esattamente quel
# messaggio. Con isMinifyEnabled = true e nessuna regola qui dentro, il difetto
# esisteva solo nell'APK di release: in debug non si minifica, quindi in
# sviluppo non si e' mai visto. Lo vedevano solo le persone che scaricavano.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase { *; }
-dontwarn androidx.room.paging.**

# --- La nostra rete e il nostro protocollo -----------------------------
# TALKY1 e' documentato in docs/TALKY1.md e deve restare leggibile nelle
# tracce di Crashlytics: se il walkie non si collega, il nome della classe
# nello stack e' la prima cosa che si guarda.
-keep class com.immaginet.talky.protocol.** { *; }
-keep class com.immaginet.talky.net.** { *; }