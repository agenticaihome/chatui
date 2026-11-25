plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from the environment (see example.env). Debug
// builds need none of it. CI sets SUPERAPP_UNSIGNED_RELEASE=1 to build the
// release APKs unsigned; the publish job of the release workflow signs them.
val releaseStore: String? = System.getenv("ARGUS_KEYSTORE")
val unsignedRelease = System.getenv("SUPERAPP_UNSIGNED_RELEASE") == "1"

android {
    namespace = "org.celaut.superapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time; desugar for older APIs.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "org.celaut.superapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "x86_64")
            isUniversalApk = true
        }
    }

    // libwallet_ffi.so is built for arm64-v8a and x86_64 only. Dependencies
    // (zxing-cpp, CameraX, DataStore) ship armeabi-v7a natives, and the
    // universal APK picked them up in alpha.57's build, which would let a
    // 32-bit device install an app that dies loading the wallet library.
    packaging {
        jniLibs {
            excludes += listOf("lib/armeabi-v7a/**", "lib/x86/**")
        }
    }

    signingConfigs {
        create("release") {
            if (!releaseStore.isNullOrBlank()) {
                val storePassword = System.getenv("ARGUS_KEYSTORE_PASSWORD")
                val keyAlias = System.getenv("ARGUS_KEY_ALIAS")
                val keyPassword = System.getenv("ARGUS_KEY_PASSWORD")
                    ?: storePassword
                require(!storePassword.isNullOrBlank()) { "ARGUS_KEYSTORE_PASSWORD is required" }
                require(!keyAlias.isNullOrBlank()) { "ARGUS_KEY_ALIAS is required" }
                require(!keyPassword.isNullOrBlank()) { "ARGUS_KEY_PASSWORD is required" }
                storeFile = file(releaseStore)
                this.storePassword = storePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }

    buildTypes {
        release {
            if (!releaseStore.isNullOrBlank()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// The release build type is configured on every build, debug ones included,
// so its keystore is required only once the task graph shows a release
// variant is actually being assembled, packaged or bundled. A debug build
// then needs no signing values; a release build without them stops here,
// before anything runs, with the message below.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { task ->
        task.project.path == project.path &&
            Regex("^(assemble|package|bundle)\\w*Release$").matches(task.name)
    }
    if (buildsRelease && !unsignedRelease) {
        require(!releaseStore.isNullOrBlank()) {
            "Release builds require ARGUS_KEYSTORE. Copy example.env to .env and set the signing values."
        }
    }
}

// libwallet_ffi.so is not tracked. Build it from rust/ with
// scripts/build_android.sh before the native libraries are merged, so a plain
// `flutter build apk` cannot package an APK without the wallet library. Gradle
// skips the task when no Rust input changed since the last build.
val repoRoot: File = rootProject.projectDir.resolve("../..")
val buildWalletFfi by tasks.registering(Exec::class) {
    description = "Builds libwallet_ffi.so for arm64-v8a and x86_64 with cargo-ndk."
    val rustDir = repoRoot.resolve("rust")
    val script = repoRoot.resolve("scripts/build_android.sh")
    inputs.files(fileTree(rustDir.resolve("crates")))
    inputs.files(
        rustDir.resolve("Cargo.toml"),
        rustDir.resolve("Cargo.lock"),
        rustDir.resolve("rust-toolchain.toml"),
        script,
    )
    outputs.files(
        listOf("arm64-v8a", "x86_64").map { file("src/main/jniLibs/$it/libwallet_ffi.so") }
    )
    commandLine("bash", script.path)
    doFirst {
        // Use the NDK that this Gradle build uses (flutter.ndkVersion), unless
        // the caller chose one.
        if (System.getenv("ANDROID_NDK_HOME").isNullOrBlank()) {
            environment("ANDROID_NDK_HOME", android.ndkDirectory.path)
        }
    }
}
tasks.named("preBuild") { dependsOn(buildWalletFfi) }

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("androidx.biometric:biometric:1.1.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
