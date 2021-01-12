pipeline {
  agent { label 'mac' }
  options {
    skipStagesAfterUnstable()
  }
  stages {
    stage('Checkout') {
      steps {
        checkout scm
        }
    }
    stage('Build & test') {
      steps {
        set -o pipefail && sh 'xcodebuild -scheme "speccyMac" -configuration "Debug" build test -destination "platform=macOS,arch=x86_64" | /usr/local/bin/xcpretty -r junit'
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
