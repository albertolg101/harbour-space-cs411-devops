pipeline {
    agent any

    environment {
        IMAGE = "ttl.sh/albertolg101:2h"
        KUBE_ARGS = '--server=https://kubernetes:6443 --insecure-skip-tls-verify=true'
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

        stage('Deploy: Kubernetes') {
            steps {
                withCredentials([string(credentialsId: 'k8s-token', variable: 'K8S_TOKEN')]) {
                    sh '''
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" delete pod myapp --ignore-not-found=true
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" apply -f k8s/pod.yaml
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" apply -f k8s/service.yaml
                        kubectl ${KUBE_ARGS} --token="$K8S_TOKEN" wait --for=condition=Ready pod/myapp --timeout=120s
                    '''
                }
            }
        }
    }
}
