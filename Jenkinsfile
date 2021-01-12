pipeline {
  agent any
  stages {
    stage('Checkout/Build/Test') {
    // Checkout files.
    checkout([
      $class: 'GitSCM',
      branches: [[name: env.BRANCH_NAME]],
      doGenerateSubmoduleConfigurations: false,
      extensions: [], submoduleCfg: [],
      userRemoteConfigs: [[
          name: 'github',
          url: 'git@github.com:shaymanjohn/speccyMac.git'
          ]]
      ])
    }

    stage('Build & test') {
        sh 'xcodebuild -scheme "speccyMac" -configuration "Debug" build test -destination "platform=macOS,arch=x86_64" -enableCodeCoverage YES | /usr/local/bin/xcpretty -r junit'
        step([$class: 'JUnitResultArchiver', allowEmptyResults: true, testResults: 'build/reports/junit.xml'])
    }
  }

  post {
    success {
      slackSend channel: '#build', message: 'speccyMac - build and test success.', teamDomain: 'karmatoad', token: 'swhGys1CY11kbCNtmypRvGL0'
    }
    failure {
      slackSend channel: '#build', message: 'speccyMac - build failure.', teamDomain: 'karmatoad', token: 'swhGys1CY11kbCNtmypRvGL0'
    }
    aborted {
      slackSend channel: '#build', message: 'speccyMac - build aborted.', teamDomain: 'karmatoad', token: 'swhGys1CY11kbCNtmypRvGL0'
    }
    unstable {
      slackSend channel: '#build', message: 'speccyMac - unstable.', teamDomain: 'karmatoad', token: 'swhGys1CY11kbCNtmypRvGL0'
    }
  }
}
