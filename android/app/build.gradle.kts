import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release 서명 (순서): ① android/key.properties ② 환경 변수 ANDROID_UPLOAD_*
// android.signReleaseWithDebug=true (또는 ANDROID_SIGN_RELEASE_WITH_DEBUG=1) 이면 Release도 디버그 키로 서명 — Play 업로드 불가.
val signReleaseWithDebug =
    (
        (rootProject.findProperty("android.signReleaseWithDebug")?.toString()?.equals("true", ignoreCase = true) == true) ||
            (System.getenv("ANDROID_SIGN_RELEASE_WITH_DEBUG")?.equals("true", ignoreCase = true) == true) ||
            (System.getenv("ANDROID_SIGN_RELEASE_WITH_DEBUG") == "1")
    )

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

val uploadStoreFileEnv = System.getenv("ANDROID_UPLOAD_STORE_FILE")?.trim()?.takeIf { it.isNotEmpty() }
val uploadStorePasswordEnv = System.getenv("ANDROID_UPLOAD_STORE_PASSWORD").orEmpty()
val uploadKeyAliasEnv = System.getenv("ANDROID_UPLOAD_KEY_ALIAS")?.trim()?.takeIf { it.isNotEmpty() }
val uploadKeyPasswordEnv = System.getenv("ANDROID_UPLOAD_KEY_PASSWORD").orEmpty()

android {
    namespace = "com.goodwill.laon"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }

    defaultConfig {
        applicationId = "com.goodwill.laon"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!signReleaseWithDebug) {
            val propsPath = keystoreProperties.getProperty("storeFile")
            val propsStoreFile = propsPath?.let { rootProject.file(it) }
            val propsOk =
                keystorePropertiesFile.exists() &&
                    propsStoreFile != null &&
                    propsStoreFile.isFile &&
                    !keystoreProperties.getProperty("storePassword").isNullOrBlank() &&
                    !keystoreProperties.getProperty("keyPassword").isNullOrBlank() &&
                    !keystoreProperties.getProperty("keyAlias").isNullOrBlank()

            val envStoreFile = uploadStoreFileEnv?.let { rootProject.file(it) }
            val envOk =
                uploadStoreFileEnv != null &&
                    envStoreFile != null &&
                    envStoreFile.isFile &&
                    uploadKeyAliasEnv != null &&
                    uploadStorePasswordEnv.isNotBlank() &&
                    uploadKeyPasswordEnv.isNotBlank()

            when {
                propsOk ->
                    create("release") {
                        keyAlias = keystoreProperties.getProperty("keyAlias")
                        keyPassword = keystoreProperties.getProperty("keyPassword")
                        storeFile = propsStoreFile
                        storePassword = keystoreProperties.getProperty("storePassword")
                    }
                envOk ->
                    create("release") {
                        storeFile = envStoreFile
                        storePassword = uploadStorePasswordEnv
                        keyAlias = uploadKeyAliasEnv!!
                        keyPassword = uploadKeyPasswordEnv
                    }
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (signReleaseWithDebug) {
                    signingConfigs.getByName("debug")
                } else {
                    signingConfigs.findByName("release")
                        ?: signingConfigs.getByName("debug")
                }
        }
    }
}

/** 업로드 키 없이 Release 빌드하면 Play 거절되므로 기본은 중단. signReleaseWithDebug 시에는 생략. */
afterEvaluate {
    if (signReleaseWithDebug) return@afterEvaluate
    listOf("bundleRelease", "assembleRelease").forEach { taskName ->
        tasks.findByName(taskName)?.doFirst {
            if (android.signingConfigs.findByName("release") == null) {
                throw org.gradle.api.GradleException(
                    """
                    Play 업로드용 릴리스 서명이 없습니다. 디버그 키로는 업로드할 수 없습니다.

                    방법 1) android/key.properties 생성 (android/key.properties.example 참고)
                      - Play Console에 등록된 업로드 키와 같은 .jks/.keystore · 비밀번호 · alias

                    방법 2) 환경 변수 (store 파일은 절대 경로 권장)
                      ANDROID_UPLOAD_STORE_FILE
                      ANDROID_UPLOAD_STORE_PASSWORD
                      ANDROID_UPLOAD_KEY_ALIAS
                      ANDROID_UPLOAD_KEY_PASSWORD

                    키스토어 지문(SHA1)은 Play Console → 앱 서명의 업로드 키 인증서와 일치해야 합니다.
                    """.trimIndent(),
                )
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.glance:glance-appwidget:1.0.0")
}
