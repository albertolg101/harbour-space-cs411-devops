pipeline {
    agent any

    tools {
       go "1.24.1"
    }

    stages {
        stage('Build') {
            steps {
                sh "GOOS=linux GOARCH=amd64 go build -trimpath -buildvcs=false -o main app/main.go"
            }
        }

        stage('Provision') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                    sshUserPrivateKey(credentialsId: 'cs411-cicd-ssh-key', keyFileVariable: 'SSH_KEY')
                ]) {
                    sh '''
                        export AWS_DEFAULT_REGION=eu-west-3
                        PUB_KEY=$(ssh-keygen -y -f $SSH_KEY)
                        terraform -chdir=terraform init -input=false
                        terraform -chdir=terraform apply -input=false -auto-approve \
                            -var "public_key=$PUB_KEY"
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                    sshUserPrivateKey(credentialsId: 'cs411-cicd-ssh-key', keyFileVariable: 'SSH_KEY')
                ]) {
                    sh '''
                        export AWS_DEFAULT_REGION=eu-west-3
                        IP=$(terraform -chdir=terraform output -raw public_ip)
                        echo "EC2 public IP: $IP"

                        for i in $(seq 1 30); do
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no \
                                -o ConnectTimeout=5 ubuntu@$IP true && break
                            echo "Waiting for SSH... ($i)"; sleep 5
                        done

                        ansible-playbook \
                            -i "$IP," \
                            --private-key $SSH_KEY \
                            --user ubuntu \
                            --ssh-common-args '-o StrictHostKeyChecking=no' \
                            playbook.yml
                    '''
                }
            }
        }
    }
}
