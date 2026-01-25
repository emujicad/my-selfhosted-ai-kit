import hudson.security.*
import hudson.util.Secret
import jenkins.model.*

// Dynamic class loading to work around default classloader visibility
def loadOicClass(String className) {
    return jenkins.model.Jenkins.instance.pluginManager.getPlugin("oic-auth").classLoader.loadClass(className)
}

def env = System.getenv()
def clientId = env['JENKINS_OIDC_CLIENT_ID']
def clientSecret = env['JENKINS_OIDC_CLIENT_SECRET']
def keycloakUrl = env['KEYCLOAK_URL_PUBLIC'] ?: "http://localhost:8080"
def realmName = env['KEYCLOAK_REALM'] ?: "master"

println "---[ AUTOMATION ]--- Configuring OIDC for Client ID: ${clientId}"

// Internal Networking (Back-channel)
def internalKeycloakUrl = "http://keycloak:8080"
def tokenServerUrl = "${internalKeycloakUrl}/realms/${realmName}/protocol/openid-connect/token"
def userInfoUrl = "${internalKeycloakUrl}/realms/${realmName}/protocol/openid-connect/userinfo"
def jwksUrl = "${internalKeycloakUrl}/realms/${realmName}/protocol/openid-connect/certs"

// Public Networking (Front-channel / Issuer)
def authServerUrl = "${keycloakUrl}/realms/${realmName}/protocol/openid-connect/auth"
def issuerUrl = "${keycloakUrl}/realms/${realmName}"

try {
    // Load Classes
    def ManualConfigClass = loadOicClass("org.jenkinsci.plugins.oic.OicServerManualConfiguration")
    def OicRealmClass = loadOicClass("org.jenkinsci.plugins.oic.OicSecurityRealm")

    // 1. Instantiate Server Configuration
    // Use (Issuer, Token, Auth) constructor
    def serverConfig = ManualConfigClass.newInstance(issuerUrl, tokenServerUrl, authServerUrl)
    
    // Set Endpoints
    serverConfig.setJwksServerUrl(jwksUrl)
    serverConfig.setUserInfoServerUrl(userInfoUrl)
    serverConfig.setScopes("openid email profile")

    // 2. Prepare Secret
    def secret = Secret.fromString(clientSecret)

    // 3. Prepare Strategies
    def strategy = new jenkins.model.IdStrategy.CaseInsensitive()

    // 4. Instantiate Realm
    def oicRealm = OicRealmClass.newInstance(
        clientId,
        secret,
        serverConfig, 
        true, // disableSslVerification (Relaxed for internal network)
        strategy, 
        strategy
    )

    // 5. Configure User Mapping Fields (CRITICAL FIX)
    // These methods belong to OicSecurityRealm, NOT ServerConfiguration
    oicRealm.setUserNameField("preferred_username")
    oicRealm.setFullNameFieldName("name")
    oicRealm.setEmailFieldName("email")
    // oicRealm.setGroupsFieldName("groups") // Optional

    // 6. Apply
    def authStrategy = new FullControlOnceLoggedInAuthorizationStrategy()
    Jenkins.instance.setSecurityRealm(oicRealm)
    Jenkins.instance.setAuthorizationStrategy(authStrategy)
    Jenkins.instance.save()
    println "---[ AUTOMATION ]--- OIDC Security Realm Configured Successfully (with User Mapping)"

} catch (Exception e) {
    println "---[ AUTOMATION ]--- ERROR: Could not configure OIDC."
    println e
    e.printStackTrace()
}
