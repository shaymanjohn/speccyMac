pipeline {
    agent { label 'mac' }
    options {
        skipStagesAfterUnstable()
    }
    environment {
        scheme = 'speccyMac'
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
        stage('Build & test') {
            steps {
                sh './BuildScripts/jenkins-build.sh ${scheme}'
//              step([$class: 'JUnitResultArchiver', allowEmptyResults: true, testResults: 'build/reports/junit.xml'])
            }
        }
    }
    post {
        always {
            slackSend(channel: "#build", message: "speccyMac build result:")
        }
        success {
            echo 'Success.'
            slackSend(channel: "#build", message: "speccyMac - build and test success.")
        }
        failure {
            echo 'Failure.'
            slackSend(channel: "#build", message: "speccyMac - build failure.")
        }
        aborted {
            echo 'Aborted.'
            slackSend(channel: "#build", message: "speccyMac - build aborted.")
        }
        unstable {
            echo 'Unstable.'
            slackSend(channel: "#build", message: "speccyMac - unstable.")
        }
    }
}
