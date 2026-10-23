import java.io.File
import java.io.FileReader
import java.util.Properties

pluginManagement {
    val flutterSdkPath: String = run {
        val properties = java.util.Properties()
        java.io.FileReader(java.io.File(rootProject.projectDir, "local.properties")).use { reader -> properties.load(reader) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.2.2" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
