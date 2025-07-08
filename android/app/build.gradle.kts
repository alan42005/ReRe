plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.reminder_app"
    
    // FIX: Updated compileSdk to 35 as required by path_provider_android.
    compileSdk = 35
    
    // Set the specific NDK version required by the plugins.
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Enable core library desugaring, required by the notifications plugin.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.reminder_app"
        minSdk = 21 // It's good practice to set a specific minSdk
        // Match targetSdk with compileSdk
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Add the dependencies block with the desugaring library.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
