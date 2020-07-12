pipeline {
  environment {
    REGISTRY = "ijo42/launcher"
    VERSION = "latest"
  }
  agent any
  stages {
    stage('Downloading artifacts') {
      steps {
        sh label: '', script: '''TAG="latest" && if [ ! "${VERSION}" = "latest" ]; then TAG="tags/${VERSION}"; fi && wget -O artficats.zip $(curl -s https://api.github.com/repos/GravitLauncher/Launcher/releases/${TAG}| grep browser_download_url | cut -d \'"\' -f 4) && unzip artficats.zip -d ./ls && unzip ./ls/libraries.zip -d ./ls && rm -f ./ls/libraries.zip'''
        }
    }
    stage('Building image') {
      steps{
        script {
          dockerImage = docker.build(REGISTRY)
        }
      }
    }
    stage('Deploy Image') {
      steps{
        script {
        withDockerRegistry(credentialsId: 'hub') {
            dockerImage.push("${VERSION}")
            }
        }
      }
    }
    stage('Remove Unused docker image') {
      steps{
        sh "docker rmi ${REGISTRY}:${VERSION}"
        cleanWs()
      }
    }
  }
}