// android/app/build.gradle.kts
import java.util.Properties // Keep this import
import kotlin.io.path.exists
import kotlin.io.path.inputStream
import kotlin.io.use
import kotlin.text.toIntOrNull

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Function to read version code and name from local.properties or default
fun getFlutterVersionCode(): Int {
    val localProperties = Properties()
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { localProperties.load(it) }
    }
    return localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
}

fun getFlutterVersionName(): String {
    val localProperties = Properties()
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { localProperties.load(it) }
    }
    return localProperties.getProperty("flutter.versionName") ?: "1.0"
}

android {
    namespace = "com.example.grubtap"
    compileSdk = 35 // ✅ *** UPDATED AS REQUIRED ***

    ndkVersion = "27.0.12077973" // Ensure this is appropriate for your project needs.
    // If you encounter NDK issues later, you might need to update this too.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.grubtap"

        val minSdkString: String? = project.findProperty("flutter.minSdkVersion") as? String
        minSdk = minSdkString?.toIntOrNull() ?: 21 // Keep this as determined by Flutter or your minimum requirement

        // Updated default for targetSdk to align better with compileSdk
        val targetSdkString: String? = project.findProperty("flutter.targetSdkVersion") as? String
        targetSdk = targetSdkString?.toIntOrNull() ?: 35 // ✅ *** UPDATED DEFAULT FOR GOOD PRACTICE ***

        versionCode = getFlutterVersionCode()
        versionName = getFlutterVersionName()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // For debug/testing only
            // TODO: Configure your release signing properly for production.
            // isMinifyEnabled = true
            // isShrinkResources = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Add Android-specific dependencies here if necessary
}
