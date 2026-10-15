import java.io.FileInputStream
import java.util.Properties
import java.util.Base64
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val dartDefines = (project.findProperty("dart-defines") as? String).orEmpty()
    .split(",").filter { it.isNotBlank() }.associate {
        val decoded = String(Base64.getDecoder().decode(it))
        val pair = decoded.split("=", limit = 2)
        pair[0] to pair.getOrElse(1) { "" }
    }
val appChannel = dartDefines["BLAB_APP_CHANNEL"] ?: "public"
if (appChannel !in listOf("public", "test")) throw GradleException("Invalid BLAB_APP_CHANNEL")
val isTestApp = appChannel == "test"
if (isTestApp && dartDefines["BLAB_ENV"] == "production") {
    throw GradleException("Blab Test cannot target production")
}

// Release signing uses an owner-controlled upload key outside Git. Release
// tasks fail closed when the local properties or keystore are unavailable.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val googleServicesFile = file("google-services.json")
if (releaseBuildRequested && !googleServicesFile.isFile) {
    throw GradleException(
        "Firebase Android configuration is required for release builds. " +
            "Place google-services.json in android/app/.",
    )
}
val requiredSigningProperties = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
if (releaseBuildRequested && !hasReleaseKeystore) {
    throw GradleException(
        "Release signing is required. Run scripts/setup_android_signing.sh " +
            "from the repository root or create android/key.properties.",
    )
}
if (hasReleaseKeystore) {
    val missingProperties = requiredSigningProperties.filter {
        keystoreProperties.getProperty(it).isNullOrBlank()
    }
    if (missingProperties.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is missing: ${missingProperties.joinToString()}",
        )
    }
    val configuredStoreFile = file(keystoreProperties.getProperty("storeFile"))
    if (!configuredStoreFile.isFile) {
        throw GradleException(
            "Release keystore does not exist: ${configuredStoreFile.absolutePath}",
        )
    }
}

android {
    namespace = "blab.nastia.ez"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = if (isTestApp) "blab.nastia.ez.test" else "blab.nastia.ez"
        manifestPlaceholders["blabAppLabel"] = if (isTestApp) "Blab-test" else "@string/app_name"
        manifestPlaceholders["blabScheme"] = if (isTestApp) "blab-test" else "blab"
        manifestPlaceholders["blabInvitePath"] = if (isTestApp) "/i-test/" else "/i/"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24  // tech-spec.md § Platform Targets
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.android.installreferrer:installreferrer:2.2")
}
