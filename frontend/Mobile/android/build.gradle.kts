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
    project.evaluationDependsOn(":app")

    // Neki paketi (npr. flutter_timezone) imaju svoju internu Kotlin konfiguraciju
    // koja se ne poklapa sa Java 17 podešavanjem u ovom projektu, što izaziva
    // "Inconsistent JVM-target compatibility" grešku pri build-u. Ovo nameće
    // istu, konzistentnu verziju svim modulima (uključujući pakete).
    fun applyConsistentJvmTarget() {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.let { androidExt ->
            androidExt.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }

    // ":app" već ima ispravno Java 17 podešavanje u svom build.gradle.kts, i
    // AGP ga do ovog trenutka već "zaključa" - ponovno postavljanje baca
    // grešku ("sourceCompatibility has been finalized"). Fix treba samo
    // paketima (npr. flutter_timezone), pa :app preskačemo.
    if (project.name != "app") {
        if (project.state.executed) {
            applyConsistentJvmTarget()
        } else {
            afterEvaluate { applyConsistentJvmTarget() }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}