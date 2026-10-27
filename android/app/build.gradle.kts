import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La clave y sus contraseñas permanecen fuera de Git. Una release nunca debe
// volver silenciosamente a la firma debug, que no sirve como identidad estable.
val releaseSigningFile = System.getenv("ENTRENAOP_ANDROID_SIGNING_PROPERTIES")
    ?.let { file(it) } ?: rootProject.file("key.properties")
val releaseSigning = Properties()
if (releaseSigningFile.isFile) {
    releaseSigningFile.inputStream().use { releaseSigning.load(it) }
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").forEach { name ->
        require(!releaseSigning.getProperty(name).isNullOrBlank()) {
            "Falta $name en la configuración privada de firma Android."
        }
    }
    require(file(releaseSigning.getProperty("storeFile")).isFile) {
        "No se encuentra el almacén privado de firma Android."
    }
}
gradle.taskGraph.whenReady {
    if (allTasks.any { it.path.startsWith(":app:") && it.name.contains("Release") }) {
        require(releaseSigningFile.isFile) {
            "Una release necesita android/key.properties o ENTRENAOP_ANDROID_SIGNING_PROPERTIES; consulta docs/ANDROID_BETA.md."
        }
    }
}

// Los mismos identificadores públicos de Dart generan el arranque nativo de
// Firebase. Sin estos recursos, Android no podría recibir al cerrar Flutter.
// No se activa ni se añade configuración de proveedor en la build habitual.
val pushDefines = (project.findProperty("dart-defines") as? String).orEmpty()
    .split(',').filter { it.isNotBlank() }.associate { encoded ->
        val decoded = String(Base64.getDecoder().decode(encoded), Charsets.UTF_8).split('=', limit = 2)
        require(decoded.size == 2) { "dart-defines incompleto" }
        decoded[0] to decoded[1]
    }
val nativePushEnabled = pushDefines["PUSH_ENABLED"] == "true" &&
    (pushDefines["APP_ENV"] ?: "development") == "development"
val nativePushResources = mapOf(
    "google_app_id" to "PUSH_FIREBASE_ANDROID_APP_ID",
    "google_api_key" to "PUSH_FIREBASE_ANDROID_API_KEY",
    "gcm_defaultSenderId" to "PUSH_FIREBASE_SENDER_ID",
    "project_id" to "PUSH_FIREBASE_PROJECT_ID",
)

android {
    namespace = "com.entrenaOp.entrenaop"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = nativePushEnabled
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.entrenaOp.entrenaop"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        if (nativePushEnabled) {
            nativePushResources.forEach { (resourceName, defineName) ->
                val configured = pushDefines[defineName]
                require(!configured.isNullOrBlank()) { "Falta $defineName para activar push en Dev" }
                resValue("string", resourceName, configured)
            }
        }
    }

    signingConfigs {
        if (releaseSigningFile.isFile) {
            create("release") {
                storeFile = file(releaseSigning.getProperty("storeFile"))
                storePassword = releaseSigning.getProperty("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningFile.isFile) {
                signingConfig = signingConfigs.getByName("release")
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
