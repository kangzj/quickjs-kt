// Adds a file repository named "yonto" for scripts/publish-yonto.sh, which writes the checksums
// and maven-metadata.xml a published repository has and Maven Local does not.
gradle.projectsEvaluated {
    allprojects {
        extensions.findByType<PublishingExtension>()?.repositories?.maven {
            name = "yonto"
            url = uri(System.getProperty("yonto.repo"))
        }
    }
}
