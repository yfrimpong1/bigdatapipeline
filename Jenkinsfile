pipeline {
  agent any

  stages {
    stage('Checkout') {
      steps {
        // git 'https://github.com/yfrimpong1/bigdatapipeline.git'
        checkout scm
      }
    }

    stage('Deploy Big Data Pipeline') {
      steps {
        // Make the script executable and run it
        sh 'chmod +x deploy.sh'
        sh './deploy.sh'
      }
    }
  }
}
