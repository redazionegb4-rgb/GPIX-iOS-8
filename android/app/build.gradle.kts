plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.gpix.gpix"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.gpix.gpix"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        ndk { abiFilters += setOf("armeabi-v7a", "arm64-v8a", "x86_64") }
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("beta") {
            storeFile = rootProject.file("gpix-test.jks")
            storePassword = "android"
            keyAlias = "gpix-beta"
            keyPassword = "android"
        }
    }
    buildTypes {
        release {
            // Public beta signing key. Replace before production.
            signingConfig = signingConfigs.getByName("beta")
        }
    }
}

flutter {
    source = "../.."
}

dependencies { implementation("androidx.exifinterface:exifinterface:1.4.2") }

if (file("google-services.json").exists()) { apply(plugin = "com.google.gms.google-services") }
