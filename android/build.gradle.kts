allprojects {
    buildscript.configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.android.tools.build" && requested.name == "gradle") useVersion("8.9.1")
            if (requested.group == "org.jetbrains.kotlin" && requested.name == "kotlin-gradle-plugin") useVersion("2.1.0")
            if (requested.group == "org.jetbrains.kotlinx" && requested.name in listOf("kotlinx-coroutines-core", "kotlinx-coroutines-core-jvm", "kotlinx-coroutines-android")) useVersion("1.8.1")
        }
    }
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Compile plugins against the AndroidX Core version selected by the app runtime.
subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.core" && requested.name in listOf("core", "core-ktx")) {
                useVersion("1.18.0")
                because("Keep plugin compile classpaths aligned with the application runtime")
            }
            if (requested.group == "androidx.annotation" && requested.name in listOf("annotation", "annotation-jvm")) {
                useVersion("1.9.1")
                because("Use the same AndroidX annotations in plugins and application")
            }
            if (requested.group == "androidx.activity" && requested.name in listOf("activity", "activity-ktx")) {
                useVersion("1.12.4")
            }
            if (requested.group == "androidx.lifecycle") {
                useVersion("2.8.7")
            }
            if (requested.group == "androidx.exifinterface" && requested.name == "exifinterface") {
                useVersion("1.4.2")
            }
        }
    }
}
