#!groovy

import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()
def env = System.getenv()

def adminUser = env.JENKINS_ADMIN_USER ?: 'admin'
def adminPassword = env.JENKINS_ADMIN_PASSWORD ?: 'admin'

println "---[ AUTOMATION ]--- Configuring Jenkins Admin User: ${adminUser}"

// 1. Create Admin User
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount(adminUser, adminPassword)
instance.setSecurityRealm(hudsonRealm)

// 2. Authorization Strategy (Full Control for Admin)
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// 3. Disable Setup Wizard (Explicitly)
def installState = instance.getInstallState()
if (!installState.isSetupComplete()) {
    println "---[ AUTOMATION ]--- Marking Setup Wizard as Complete"
    instance.setInstallState(jenkins.install.InstallState.INITIAL_SETUP_COMPLETED)
}

instance.save()
println "---[ AUTOMATION ]--- Jenkins Admin Created & Setup Wizard Disabled"
