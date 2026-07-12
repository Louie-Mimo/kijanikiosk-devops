pipeline {
    agent any

    environment {
        NODE_ENV = 'test'
        BUILD_DIR = 'dist'
        APP_NAME = 'kijanikiosk-payments'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {

        stage('Build') {
            steps {
                dir('week5/payments') {

                    echo "Installing dependencies..."

                    sh '''
                        set -e
                        npm ci
                    '''

                    echo "Building application..."

                    sh '''
                        set -e
                        npm run build
                    '''

                    echo "Verifying build output..."

                    sh '''
                        set -e
                        test -d "${BUILD_DIR}"
                        echo "Files in build directory:"
                        ls ${BUILD_DIR}
                        echo "Count:"
                        ls ${BUILD_DIR} | wc -l
                    '''
                }
            }
        }

        stage('Test') {
            steps {
                dir('week5/payments') {

                    echo "Running tests..."

                    sh '''
                        set -e
                        npm test
                    '''
                }
            }

            post {
                always {
                    junit allowEmptyResults: true,
                          testResults: 'week5/payments/test-results/*.xml'
                }
            }
        }

        stage('Archive') {
            steps {

                archiveArtifacts artifacts: 'week5/payments/dist/**',
                                 fingerprint: true,
                                 onlyIfSuccessful: true
            }
        }
    }

    post {

        success {
            echo "Pipeline succeeded: ${APP_NAME} build ${BUILD_NUMBER}"
            echo "Artifact URL: ${BUILD_URL}artifact/"
        }

        failure {
            echo "Pipeline FAILED: ${APP_NAME} build ${BUILD_NUMBER}"
            echo "Check the Jenkins console log."
        }

        always {
            cleanWs()
        }
    }
}
