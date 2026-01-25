import jenkins.model.*
import jenkins.model.JenkinsLocationConfiguration

def env = System.getenv()
// Use the existing var from docker-compose or fallback
def jenkinsUrl = env['JENKINS_URL_PUBLIC'] ?: "http://localhost:8081/"

println "---[ AUTOMATION ]--- Configuring Jenkins Location URL: ${jenkinsUrl}"

def config = JenkinsLocationConfiguration.get()
if (config.getUrl() != jenkinsUrl) {
    config.setUrl(jenkinsUrl)
    config.setAdminAddress("admin@example.com") 
    config.save()
    println "---[ AUTOMATION ]--- Jenkins Location URL updated."
} else {
    println "---[ AUTOMATION ]--- Jenkins Location URL already set."
}
