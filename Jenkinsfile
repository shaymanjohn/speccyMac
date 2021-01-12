pipeline {
  agent { label 'mac' }
  options {
    skipStagesAfterUnstable()
  }
  environment {
    appScheme = 'speccyMac'
  }
  stages {
    stage('Checkout') {
      steps {
        checkout scm
        }
    }
    stage('Build & test') {
      steps {
        sh './BuildScripts/build-for-validating-sh {appScheme}'
        step([$class: 'JUnitResultArchiver', allowEmptyResults: true, testResults: 'build/reports/junit.xml'])
      }
    }
  }
  post {
    always {
      slackSend channel: '#build', message: 'speccyMac build result:', teamDomain: 'karmatoad', token: 'swhGys1CY11kbCNtmypRvGL0'
    }
    success {
      echo 'Great success.'
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
