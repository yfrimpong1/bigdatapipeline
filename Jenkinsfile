pipeline {
  agent any

  stages {
    stage('Checkout') {
      steps {
        git 'https://github.com/yfrimpong1/bigdatapipeline.git'
      }
    }

    stage('Deploy Big Data Pipeline') {
      steps {
        sh 'chmod +x deploy.sh'
        sh './deploy.sh'
      }
    }
  }
}
