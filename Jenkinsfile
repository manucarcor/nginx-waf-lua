// Jenkinsfile de referencia (genérico, sin librerías compartidas internas).
//
// El proyecto del que parte esta demo se construía originalmente en un
// Jenkins interno usando una librería compartida propia de la empresa
// (@Library) y un agente Swarm específico. Aquí se deja una versión
// autocontenida, sin dependencias externas, solo para mostrar cómo sería
// el mismo pipeline en Jenkins. El CI que realmente se ejecuta en este
// repositorio público es el de GitHub Actions (.github/workflows/ci.yml).
pipeline {
    agent any

    environment {
        IMAGE_NAME = "nginx-waf-lua"
        // Sustituye por tu propio registro, p. ej. "tu-registro.example.com"
        REGISTRY   = "registry.example.com"
    }

    stages {
        stage('Lint Dockerfile') {
            steps {
                sh 'docker run --rm -i hadolint/hadolint < Dockerfile'
            }
        }

        stage('Build') {
            steps {
                sh "docker build -t ${REGISTRY}/${IMAGE_NAME}:${env.BUILD_NUMBER} ."
            }
        }

        stage('Test') {
            steps {
                sh 'bash scripts/generar-certificados-dev.sh'
                sh 'docker compose up -d'
                sh 'sleep 5 && curl -kf https://localhost/healthz'
                sh 'docker compose down -v'
            }
        }

        stage('Push') {
            when { branch 'main' }
            steps {
                // Requiere credenciales configuradas en Jenkins (Credentials
                // Manager), nunca en texto plano en este fichero.
                sh "docker push ${REGISTRY}/${IMAGE_NAME}:${env.BUILD_NUMBER}"
            }
        }
    }
}
