node('mac') {

    stage('Checkout/Build/Test') {

    // Checkout files.
    checkout([
        $class: 'GitSCM',
        branches: [[name: 'master']],
        doGenerateSubmoduleConfigurations: false,
        extensions: [], submoduleCfg: [],
        userRemoteConfigs: [[
            name: 'github',
            url: 'https://github.com/shaymanjohn/speccyMac.git'
        ]]
    ])

    // Build and Test
    sh 'xcodebuild -scheme "speccyMac" -configuration "Debug" build test -destination "platform=macOS,arch=x86_64" -enableCodeCoverage YES | /usr/local/bin/xcpretty -r junit'

    // Publish test restults.
    step([$class: 'JUnitResultArchiver', allowEmptyResults: true, testResults: 'build/reports/junit.xml'])
    }

    stage('Analytics') {

    // Generate Checkstyle report
    sh '/usr/local/bin/swiftlint lint --reporter checkstyle > checkstyle.xml || true'

    // Publish checkstyle result
    step([$class: 'CheckStylePublisher', canComputeNew: false, defaultEncoding: '', healthy: '', pattern: 'checkstyle.xml', unHealthy: ''])
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                }
            }
        stage('Unlock keychain') {
            steps {
                sh './BuildScripts/unlock-keychain.sh'
            }
        }
        stage('Build') {
            steps {
                sh './BuildScripts/jenkins-build.sh ${scheme}'
            }
        }
        stage('Test') {
            steps {
                sh './BuildScripts/jenkins-test.sh ${scheme}'
                step([$class: 'JUnitResultArchiver', allowEmptyResults: true, testResults: 'build/reports/junit.xml'])
            }
        }
    }
    post {
        always {
            slackSend(message: "speccyMac build result:")
        }
        success {
            echo 'Success.'
            slackSend(message: "speccyMac - build and test success.")
        }
        failure {
            echo 'Failure.'
            slackSend(message: "speccyMac - build failure.")
        }
        aborted {
            echo 'Aborted.'
            slackSend(message: "speccyMac - build aborted.")
        }
        unstable {
            echo 'Unstable.'
            slackSend(message: "speccyMac - unstable.")
        }
    }
}
