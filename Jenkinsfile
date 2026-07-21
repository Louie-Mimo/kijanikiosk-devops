pipeline {
    agent any

    environment {
        NODE_ENV  = 'test'
        NODE_OPTIONS   = '--max-old-space-size=512'
        BUILD_DIR = 'dist' 
        APP_NAME  = 'kijanikiosk-payments'
        NEXUS_URL = 'http://13.60.193.193:8081/repository/npm-kijanikiosk/'

        // Compute versions globally from the correct directory using script expansion
        PKG_VERSION = "${sh(script: 'node -p "require(\'./week5/payments/package.json\').version"', returnStdout: true).trim()}"
        GIT_SHORT   = "${sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()}"
        ARTIFACT_VERSION = "${PKG_VERSION}-${GIT_SHORT}"
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
                    echo "Building ${APP_NAME} version ${env.ARTIFACT_VERSION}..."
                    echo "Installing dependencies..."
                    sh 'npm ci'

                    echo "Building application..."
                    sh 'npm run build'

                    echo "Verifying build output..."
                    sh '''
                        set -e
                        test -d "${BUILD_DIR}"
                        echo "Contents of ${BUILD_DIR}:"
                        ls -la ${BUILD_DIR}
                    '''
                }
            }
        }

        stage('Test') {
            steps {
                dir('week5/payments') {
                    echo "Running tests..."
                    sh 'npm test'
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'week5/payments/test-results/*.xml'
                }
            }
        }

        stage('Archive') {
            steps {
                dir('week5/payments') {
                    archiveArtifacts artifacts: "${BUILD_DIR}/**",
                                     fingerprint: true,
                                     onlyIfSuccessful: true
                }
            }
        }

        stage('Publish') {
            steps {
                dir('week5/payments') {
                    withCredentials([usernamePassword(
                        credentialsId: 'nexus-credentials',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )]) {
                        sh '''
                            set -e
                            
                            trap "rm -f .npmrc; echo '.npmrc cleaned up.'" EXIT
                            
                            # Strip http:// or https:// completely
                            NEXUS_PROTO_STRIP=$(echo "${NEXUS_URL}" | sed -E 's|https?://||')
                            
                            # Generate Base64 Auth Token
                            AUTH_TOKEN=$(printf "%s:%s" "${NEXUS_USER}" "${NEXUS_PASS}" | base64)
                            
                            # Write configuration to local .npmrc using explicit leading //
                            echo "registry=${NEXUS_URL}" > .npmrc
                            echo "//${NEXUS_PROTO_STRIP}:_auth=${AUTH_TOKEN}" >> .npmrc
                            echo "//${NEXUS_PROTO_STRIP}:always-auth=true" >> .npmrc
                            
                            # Update version and publish
                            npm version "${ARTIFACT_VERSION}" --no-git-tag-version
                            npm publish
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Published ${APP_NAME} version ${ARTIFACT_VERSION} to Nexus"
            echo "Artifact URL: ${NEXUS_URL}${APP_NAME}/-/${APP_NAME}-${ARTIFACT_VERSION}.tgz"
        }
        failure {
            echo "Pipeline FAILED at build ${BUILD_NUMBER} - check logs at ${BUILD_URL}"
        }
        always {
            cleanWs()
        }
    }
}