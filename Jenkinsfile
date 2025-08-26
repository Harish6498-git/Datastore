pipeline {
  agent any

  parameters {
    string(name: "App_Version", description: "provide application version")
  }

  environment {
    DOCKERHUB_CREDENTIALS = credentials("dockerhub")

    // SonarQube integration
    SONARQUBE_SERVER = 'SonarQube'     // Matches Jenkins > Manage Jenkins > System > SonarQube servers (Name)
    SONAR_TOKEN_CRED = 'Sonar-token'   // Jenkins credential (Secret text) storing your SonarQube token
  }

  stages {
    stage("Checkout Stage") {
      steps{
        checkout scmGit(
          branches: [[name: '*/main']],
          extensions: [],
          userRemoteConfigs: [[url: 'https://github.com/Harish6498-git/Datastore.git']]
        )
      }
    }

    stage("Building Application") {
      steps {
        sh """
          echo "-------- Building Application --------"
          mvn -B clean package
          echo "------- Application Built Successfully --------"
        """
      }
    }

    stage("Execute Testcases") {
      steps {
        sh """
          echo "-------- Executing Testcases --------"
          mvn -B test
          echo "-------- Testcases Execution Complete --------"
        """
      }
    }

    // SonarQube static analysis (Maven goal)
    stage("Static Analysis - SonarQube") {
      steps {
        withSonarQubeEnv("${SONARQUBE_SERVER}") {
          withCredentials([string(credentialsId: "${SONAR_TOKEN_CRED}", variable: 'SONAR_TOKEN')]) {
            sh """
              echo "-------- Running SonarQube Analysis --------"
              mvn -B sonar:sonar \
                -Dsonar.projectKey=datastore \
                -Dsonar.projectName=datastore \
                -Dsonar.host.url=$SONAR_HOST_URL \
                -Dsonar.login=$SONAR_TOKEN
              echo "-------- SonarQube Analysis Triggered --------"
            """
          }
        }
      }
    }

    // Fail pipeline if the Quality Gate fails (requires SonarQube webhook to Jenkins)
    stage("Quality Gate") {
      steps {
        script {
          timeout(time: 10, unit: 'MINUTES') {
            def qg = waitForQualityGate abortPipeline: true
            echo "Quality Gate status: ${qg.status}"
          }
        }
      }
    }

    stage("Pushing Artifacts To S3") {
      steps {
        sh """
          echo "-------- Pushing Artifacts To S3 --------"
          aws s3 cp ./target/*.jar s3://jenkins-s3-artifacts/
          echo "-------- Pushing Artifacts To S3 Completed --------"
        """
      }
    }

    stage("Creating Docker Image") {
      steps {
        sh """
          echo "-------- Building Docker Image --------"
          docker build -t datastore:"${App_Version}" .
          echo "-------- Image Successfully Built --------"
        """
      }
    }

    stage("Scaning Docker Image") {
      steps {
        sh """
          echo "-------- Scanning Docker Image --------"
          trivy image datastore:"${App_Version}"
          echo "-------- Scanning Docker Image Complete --------"
        """
      }
    }

    stage("Tagging Docker Image") {
      steps{
        sh """
          echo "-------- Tagging Docker Image --------"
          docker tag datastore:"${App_Version}" harish0604/datastore:"${App_Version}"
          echo "-------- Tagging Docker Image Completed."
        """
      }
    }

    stage("Loggingin & Pushing Docker image To DockerHub") {
      steps {
        sh """
          echo "-------- Logging To DockerHub --------"
          docker login -u $DOCKERHUB_CREDENTIALS_USR --password $DOCKERHUB_CREDENTIALS_PSW
          echo "-------- DockerHub Login Successful --------"

          echo "-------- Pushing Docker Image To DockerHub --------"
          docker push harish/datastore:"${App_Version}"
          echo "-------- Docker Image Pushed Successfully --------"
        """
      }
    }

    stage("cleanup") {
      steps {
        sh """
           echo "-------- Cleaning Up Jenkins Machine --------"
           docker image prune -a -f
           echo "-------- Clean Up Successful --------"
        """
      }
    }

    stage("Deployment Acceptance") {
      steps {
        input 'Trigger Down Stream Job'
      }
    }

    stage("Triggering Deployment Job") {
      steps {
        build job: "KubernetesDeployment",
          parameters: [
            string(name: "App_Name", value: "datastore-deploy"),
            string(name: "App_Version", value: "${params.App_Version}")
          ]
      }
    }
  }
}

