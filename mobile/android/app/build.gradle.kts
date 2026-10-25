import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma release: key.properties (gitignored) describe el keystore.
// Si no existe (o falta el archivo .jks) se cae a la firma de debug,
// así que los builds locales y de CI sin secrets siguen funcionando.
val releaseKeyPropertiesFile = rootProject.file("key.properties")
val releaseSigningKeyProperties: Properties? = if (releaseKeyPropertiesFile.exists()) {
    Properties().apply {
        FileInputStream(releaseKeyPropertiesFile).use { properties -> load(properties) }
    }
} else {
    null
}
val releaseKeystoreConfigured: Boolean = run {
    if (releaseSigningKeyProperties == null) {
        false
    } else {
        val storeFile = releaseSigningKeyProperties.getProperty("storeFile")
        storeFile != null && rootProject.file(storeFile).exists()
    }
}

android {
    namespace = "com.goatvision.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            java.srcDir("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.goatvision.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeystoreConfigured) {
            val signingProperties = releaseSigningKeyProperties!!
            create("release") {
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
                storePassword = signingProperties.getProperty("storePassword")
                storeFile = rootProject.file(signingProperties.getProperty("storeFile"))
            }
        }
    }

    buildTypes {
        release {
            // Con keystore presente (key.properties en android/) firma
            // release; sin él cae a la clave de debug para que los
            // builds locales y de CI sin secrets sigan funcionando.
            signingConfig = if (releaseKeystoreConfigured) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
