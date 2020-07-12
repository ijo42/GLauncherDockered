pipeline {
  environment {
    registry = "ijo42/launcher"
	version = ''
  }
  agent any
  stages {
    stage('Downloading artifacts') {
      steps {
		sh label: '', script: '''TAG="latest" && if [[ -n $version ]]; then TAG="tags/$version"; fi && \\
		wget -O artficats.zip $(curl -s https://api.github.com/repos/GravitLauncher/Launcher/releases/latest | grep browser_download_url | cut -d \'"\' -f 4) && unzip artficats.zip -d ./ls'''
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
			dockerImage.push($version)
			}
        }
      }
    }
    stage('Remove Unused docker image') {
      steps{
        sh "docker rmi $registry:$version"
      }
    }
  }
}
