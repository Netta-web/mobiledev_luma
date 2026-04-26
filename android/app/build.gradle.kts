plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Reads google-services.json and wires Firebase SDK configuration.
    // The plugin version is declared in the root build.gradle.kts.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.my_luma"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications — enables Java 8+ APIs on older Android
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.my_luma"

        // Flutter's minimum supported SDK is 23 (as of Flutter 3.22+).
        // All required plugins (geolocator, FCM, local_notifications) are fine with 23.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Required for multidex (firebase + many plugins exceed 64k method limit)
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: replace with a proper signing config before publishing
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Desugaring library — required by flutter_local_notifications for Java 8+ time APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BoM manages all Firebase SDK versions in sync.
    // FlutterFire packages resolve against these versions automatically.
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))

    // Firebase Analytics — baseline SDK, enables Firebase console reporting
    implementation("com.google.firebase:firebase-analytics")
}
