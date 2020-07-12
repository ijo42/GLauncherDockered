pipeline {
  environment {
    REGISTRY = "ijo42/launcher"
    VERSION = "latest"
    RUNTIME_VERSION = "latest"
  }
  agent any
  stages {
    stage('Downloading artifacts') {
      steps {
        sh label: 'main artifacts',    script: '''TAG="latest" && if [ ! "${VERSION}" = "latest" ]; then TAG="tags/${VERSION}"; fi && wget -O artficats.zip $(curl -s https://api.github.com/repos/GravitLauncher/Launcher/releases/${TAG} | grep browser_download_url | cut -d \'"\' -f 4) && unzip artficats.zip -d ./ls && unzip ./ls/libraries.zip -d ./ls && rm -f ./ls/libraries.zip'''
        sh label: 'runtime artifacts', script: '''TAG="latest" && if [ ! "${RUNTIME_VERSION}" = "latest" ]; then TAG="tags/${VERSION}"; fi && wget -O runtime_artficats.zip $(curl -s https://api.github.com/repos/GravitLauncher/LauncherRuntime/releases/${TAG} | grep browser_download_url | cut -d \'"\' -f 4) && unzip runtime_artficats.zip -d ./ls/launcher-modules && unzip ./ls/launcher-modules/runtime.zip -d ./ls/runtime && rm ./ls/launcher-modules/runtime.zip'''
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