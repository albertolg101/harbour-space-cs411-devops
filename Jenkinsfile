pipeline {
    agent any

    environment {
        IMAGE = "ttl.sh/albertolg101:2h"
        DEPLOY_HOST = "docker"
        ANSIBLE_HOST_KEY_CHECKING = "False"
    }

    stages {
        stage('Build') {
            steps {
                sh "docker build -t ${IMAGE} ."
            }
        }

        stage('Push') {
            steps {
                sh "docker push ${IMAGE}"
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'docker-ssh-key',
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USER'
                )]) {
                    sh 'ansible-playbook -i "$DEPLOY_HOST," --private-key=$SSH_KEY --user=$SSH_USER -e image=$IMAGE playbook.yml'
                }
            }
        }
    }
}
