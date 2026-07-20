pipeline {
    agent any

    environment {
    NODE_ENV = 'test'
    BUILD_DIR = 'dist'
    APP_NAME = 'kijanikiosk-payments'

    NEXUS_URL = 'http://13.60.246.153:8081/repository/npm-kijanikiosk/'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Prepare Version') {

            steps {

                dir('week5/payments') {

                    script {

                        env.PKG_VERSION = sh(
                            script: "node -p \"require('./package.json').version\"",
                            returnStdout: true
                        ).trim()


                        env.GIT_SHORT = sh(
                            script: "git rev-parse --short HEAD",
                            returnStdout: true
                        ).trim()


                        env.ARTIFACT_VERSION =
                        "${env.PKG_VERSION}-${env.GIT_SHORT}"


                        echo "Package version: ${env.PKG_VERSION}"

                        echo "Git hash: ${env.GIT_SHORT}"

                        echo "Artifact version: ${env.ARTIFACT_VERSION}"

                    }

                }

            }
        }

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

                        echo "Contents of ${BUILD_DIR}:"

                        ls -la ${BUILD_DIR}

                        echo "Number of files:"

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

        stage('Publish') {

            steps {

                echo "Publish stage placeholder."

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
