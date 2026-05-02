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
// 둘 다 없으면 release가 debug 키로 서명되어 Play 업로드가 거절되므로, bundle/assemble Release 시 빌드를 중단한다.
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

    buildTypes {
        release {
            signingConfig =
                signingConfigs.findByName("release")
                    ?: signingConfigs.getByName("debug")
        }
    }
}

/** Release가 디버그 키로 묶이면 Play 업로드 시 서명 불일치가 나므로 즉시 실패시킨다. */
afterEvaluate {
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
