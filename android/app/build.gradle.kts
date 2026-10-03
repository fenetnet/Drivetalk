plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.drivetalk.drivetalk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.drivetalk.drivetalk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Invitation links (see AndroidManifest.xml). CI sets these from the
        // INVITE_BASE_URL repository variable; a harmless default otherwise.
        manifestPlaceholders["inviteHost"] =
            System.getenv("INVITE_HOST")?.takeIf { it.isNotBlank() }
                ?: "invite.drivetalk.invalid"
        manifestPlaceholders["invitePathPrefix"] =
            System.getenv("INVITE_PATH_PREFIX")?.takeIf { it.isNotBlank() } ?: "/i/"
    }

    // Test builds are signed with ONE stable key so updates install over the
    // previous version. The key never lives in git: CI writes it from GitHub
    // secrets and passes its path/password via environment variables.
    val testKeystore = System.getenv("DT_KEYSTORE_PATH")
    signingConfigs {
        if (testKeystore != null) {
            create("stableTest") {
                storeFile = file(testKeystore)
                storePassword = System.getenv("DT_KEYSTORE_PASSWORD")
                keyAlias = "drivetalk"
                keyPassword = System.getenv("DT_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (testKeystore != null) {
                signingConfigs.getByName("stableTest")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // In-vehicle detection (Activity Recognition Transition API).
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
