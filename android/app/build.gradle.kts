import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use(::load)
    }
}

fun signingProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?: error("Missing signing property '$name' in ${keystorePropertiesFile.path}")

android {
    namespace = "com.jingluo.goodix_ble_tool"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jingluo.goodix_ble_tool"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = rootProject.file(signingProperty("storeFile"))
            storePassword = signingProperty("storePassword")
            keyAlias = signingProperty("keyAlias")
            keyPassword = signingProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            ndk {
                abiFilters.clear()
                abiFilters.add("arm64-v8a")
            }
            
            isMinifyEnabled = true  // 启用代码压缩
            isShrinkResources = true  // 启用资源压缩
            proguardFiles("proguard-rules.pro")
        }
        debug {
            signingConfig = signingConfigs.getByName("release")
            ndk {
                abiFilters.clear()
                abiFilters.add("arm64-v8a")
            }
        }
    }
}

flutter {
    source = "../.."
}
