pipeline {
    agent { label 'mac' }
    options {
        skipDefaultCheckout true
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
