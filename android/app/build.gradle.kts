plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val nokKeystore = System.getenv("NOK_SIGNING_KEYSTORE")?.let { file(it) }
val nokPassword = System.getenv("NOK_SIGNING_PASSWORD") ?: ""
val nokHasSigning = nokKeystore?.isFile == true && nokPassword.isNotEmpty()
check((nokKeystore?.isFile == true) == nokPassword.isNotEmpty()) {
    "NOK signing configuration is incomplete: supply both the keystore and password."
}

android {
    namespace = "app.nok.nok_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.nok.nok_ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (nokHasSigning) {
            create("nokRelease") {
                storeFile = nokKeystore
                storePassword = nokPassword
                keyAlias = "nok-release"
                keyPassword = nokPassword
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        release {
            // A temporary preview is an intermediate build only. Distributed
            // APKs use the persistent key, either here or via apksigner.
            signingConfig = signingConfigs.getByName(if (nokHasSigning) "nokRelease" else "debug")
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
