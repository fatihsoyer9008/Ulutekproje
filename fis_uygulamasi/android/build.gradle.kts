allprojects {
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

    // Isar 3.1.0+1 predates AGP's mandatory namespace requirement.
    // Keep the workaround in the project so every developer and CI build gets
    // the same configuration without modifying the global Pub cache.
    if (name == "isar_flutter_libs") {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                namespace = "dev.isar.isar_flutter_libs"
            }
            extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
                finalizeDsl { libraryExtension ->
                    libraryExtension.namespace = "dev.isar.isar_flutter_libs"
                    libraryExtension.compileSdk = 36
                }
            }
        }
    }

    // camera_android_camerax 0.7.4+2 compiles CameraX 1.6.1 APIs that
    // reference CallbackToFutureAdapter, but the plugin does not expose the
    // AndroidX concurrent artifact on its Java compile classpath. Keep this
    // project-level workaround until the plugin publishes that dependency.
    if (name == "camera_android_camerax") {
        plugins.withId("com.android.library") {
            dependencies.add(
                "implementation",
                "androidx.concurrent:concurrent-futures:1.1.0",
            )
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
