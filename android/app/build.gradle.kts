import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    id("com.gladed.androidgitversion")
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
keystoreProperties.load(FileInputStream(keystorePropertiesFile))

android {
    namespace = "com.example.powertaxi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    androidGitVersion {
        project.androidGitVersion.codeFormat = "MNNPP"
        project.androidGitVersion.format = "%tag%%-commit%"
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.powertaxi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // versionCode = flutter.versionCode
        // versionName = flutter.versionName

        versionCode = androidGitVersion.code()
        versionName = androidGitVersion.name()
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    
    buildTypes {
        debug {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            // signingConfig = signingConfigs.getByName("debug")

            versionNameSuffix = "-debug"
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        create("uat") {
            // isDebuggable = true
            isMinifyEnabled = true
            isShrinkResources = true

            signingConfig = signingConfigs.getByName("release")
            // applicationIdSuffix = ".uat"
            versionNameSuffix = "-uat"
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true

            signingConfig = signingConfigs.getByName("release")
            versionNameSuffix = "-release"
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    /* 
    applicationVariants.all {
        val buildTypeName = buildType.name
        val versionName = flutter.versionName
        val versionCode = flutter.versionCode
        outputs.all {
            val apkOutput = this as? com.android.build.gradle.internal.api.ApkVariantOutputImpl
            if (apkOutput != null) {
                apkOutput.outputFileName = "powertaxi_app_v${versionName}_${versionCode}_${buildTypeName}.apk"
            }
        }
    } */

    android.applicationVariants.all {
            outputs.map { it as com.android.build.gradle.internal.api.ApkVariantOutputImpl }
                .forEach { output ->
                    val buildTypeName = buildType.name
                    val buildGitName = project.androidGitVersion.name()

                    val name = "powertaxi-v${versionName}-${buildTypeName}"
                    output.outputFileName = "${name}.apk"
                }
        }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar"))))
}
