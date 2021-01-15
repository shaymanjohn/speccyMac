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
            slackSend channel: '#build', message: 'speccyMac build result:', teamDomain: 'karmatoad', token: 'swhGys1CY11kbCNtmypRvGL0'
        }
        success {
            echo 'Success.'
            slackSend channel: '#build', message: 'speccyMac - build and test success.', teamDomain: 'karmatoad', token: 'swhGys1CY11kbCNtmypRvGL0'
        }
        failure {
            echo 'Failure.'
            slackSend channel: '#build', message: 'speccyMac - build failure.', teamDomain: 'karmatoad', token: 'swhGys1CY11kbCNtmypRvGL0'
        }
        aborted {
            echo 'Aborted.'
            slackSend channel: '#build', message: 'speccyMac - build aborted.', teamDomain: 'karmatoad', token: 'swhGys1CY11kbCNtmypRvGL0'
        }
        unstable {
            echo 'Unstable.'
            slackSend channel: '#build', message: 'speccyMac - unstable.', teamDomain: 'karmatoad', token: 'swhGys1CY11kbCNtmypRvGL0'
        }
    }
}
