pipeline {
  /* 
     'agent any' means this pipeline can run on any available executor. 
     Since you are in Docker, this assumes the Jenkins container has the host's 
     Docker socket mounted and the necessary CLIs installed.
  */
  agent any

  stages {
      // This stage checks if the required binaries are installed in the Jenkins container
      stage('Verify Tools') {
          steps {
              sh '''
                  echo "--- Checking AWS CLI ---"
                  aws --version || echo "AWS CLI not found"
                  
                  echo "--- Checking Docker ---"
                  docker --version || echo "Docker CLI not found"
                  
                  echo "--- Checking kubectl ---"
                  kubectl version --client || echo "kubectl not found"
              '''
          }
      }

      // This stage pulls your code from the GitHub repository configured in the Job SCM settings
      stage('Checkout') {
        steps {
          // 'checkout scm' fetches the specific version/branch that triggered the build
          checkout scm
        }
      }

      // This stage executes your external deployment logic
      stage('Deploy Big Data Pipeline') {
        steps {
          /* 
             1. Grant execute permissions to the script 
             2. Run the script (this performs Docker login, build, push, and EKS deployment)
          */
          sh 'chmod +x deploy.sh'
          sh './deploy.sh'
          
        }
      }
  }
}
