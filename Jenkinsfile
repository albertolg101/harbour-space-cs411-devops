pipeline {
    agent any

    tools {
       go "1.24.1"
    }

    stages {
        stage('Build') {
            steps {
                sh "go build -trimpath -buildvcs=false -o main app/main.go"
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'target-ssh',
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USER'
                )]) {
                    sh 'ansible-playbook -i hosts.ini --private-key=$SSH_KEY --user=$SSH_USER playbook.yml'
                }
            }
        }
    }
}
