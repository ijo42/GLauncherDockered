pipeline {
  environment {
    registry = "ijo42/launcher"
    VERSION = ''
  }
  agent any
  stages {
    stage('Downloading artifacts') {
      steps {
        sh label: '', script: '''TAG="latest" && if [[ -n "${VERSION}" ]]; then TAG="tags/${VERSION}"; fi && wget -O artficats.zip $(curl -s https://api.github.com/repos/GravitLauncher/Launcher/releases/${TAG}| grep browser_download_url | cut -d \'"\' -f 4) && unzip artficats.zip -d ./ls && unzip ./ls/libraries.zip -d ./ls && rm -f ./ls/libraries.zip'''
        }
    }
    stage('Building image') {
      steps{
        script {
          dockerImage = docker.build($registry)
        }
      }
    }
    stage('Deploy Image') {
      steps{
        script {
        withDockerRegistry(credentialsId: 'hub') {
            dockerImage.push($VERSION)
            }
        }
      }
    }
    stage('Remove Unused docker image') {
      steps{
        sh "docker rmi $registry:$VERSION"
        cleanWs()
      }
    }
  }
}