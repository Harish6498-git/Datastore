pipeline {
  agent any

  parameters {
    string(name: "App_Version", description: "provide application version")
  }

  environment {
    // SonarQube integration
    SONARQUBE_SERVER = 'SonarQube'     // Must match Manage Jenkins > System > SonarQube servers (Name)
    SONAR_TOKEN_CRED = 'Sonar-token'   // Jenkins credential ID (Secret text) for your Sonar token
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
        sh '''
          echo "-------- Building Application --------"
          mvn -B clean package
          echo "------- Application Built Successfully --------"
        '''
      }
    }

    stage("Execute Testcases") {
      steps {
        sh '''
          echo "-------- Executing Testcases --------"
          mvn -B test
          echo "-------- Testcases Execution Complete --------"
        '''
      }
    }

    // SonarQube static analysis (Maven goal)
    stage("Static Analysis - SonarQube") {
      steps {
        withSonarQubeEnv("${SONARQUBE_SERVER}") {
          // Expose as SONAR_TOKEN (no hyphen), use single quotes in sh so shell expands vars
          withCredentials([string(credentialsId: "${SONAR_TOKEN_CRED}", variable: 'SONAR_TOKEN')]) {
            sh '''
              echo "-------- Running SonarQube Analysis --------"
              echo "SONAR_HOST_URL=$SONAR_HOST_URL"
              mvn -B sonar:sonar \
                -Dsonar.projectKey=datastore \
                -Dsonar.projectName=datastore \
                -Dsonar.host.url=$SONAR_HOST_URL \
                -Dsonar.login=$SONAR_TOKEN
              echo "-------- SonarQube Analysis Triggered --------"
            '''
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
        sh '''
          echo "-------- Pushing Artifacts To S3 --------"
          # Upload to datastore/ prefix to match least-privilege IAM policy
          aws s3 cp ./target/*.jar s3://jenkins-s3-artifacts-datastore-app/datastore/
          echo "-------- Pushing Artifacts To S3 Completed --------"
        '''
      }
    }

    stage("Creating Docker Image") {
      steps {
        sh '''
          echo "-------- Building Docker Image --------"
          docker build -t datastore:"${App_Version}" .
          echo "-------- Image Successfully Built --------"
        '''
      }
    }

    stage("Scaning Docker Image") {
      steps {
        sh '''
          echo "-------- Scanning Docker Image --------"
          # Optional strict mode:
          # trivy --download-db-only || true
          # trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 datastore:"${App_Version}"
          trivy image datastore:"${App_Version}"
          echo "-------- Scanning Docker Image Complete --------"
        '''
      }
    }

    stage("Tagging Docker Image") {
      steps{
        sh '''
          echo "-------- Tagging Docker Image --------"
          docker tag datastore:"${App_Version}" harish0604/datastore:"${App_Version}"
          echo "-------- Tagging Docker Image Completed."
        '''
      }
    }

    stage("Loggingin & Pushing Docker image To DockerHub") {
      steps {
        // Use scoped creds + --password-stdin (safer), and push the SAME repo you tagged
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            echo "-------- Logging To DockerHub --------"
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            echo "-------- DockerHub Login Successful --------"

            echo "-------- Pushing Docker Image To DockerHub --------"
            docker push harish0604/datastore:"${App_Version}"
            echo "-------- Docker Image Pushed Successfully --------"
          '''
        }
      }
      post {
        always {
          sh '''
            echo "-------- Docker Logout --------"
            docker logout || true
          '''
        }
      }
    }

    stage("cleanup") {
      steps {
        sh '''
           echo "-------- Cleaning Up Jenkins Machine --------"
           docker image prune -a -f
           echo "-------- Clean Up Successful --------"
        '''
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
