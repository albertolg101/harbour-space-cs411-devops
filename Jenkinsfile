pipeline {
    agent any

    tools {
       go "1.24.1"
    }

    stages {
        stage('Build') {
            steps {
                sh "go build app/main.go"
            }
        }
    }
}
