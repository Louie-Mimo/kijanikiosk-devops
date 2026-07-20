pipeline {
    agent any

    environment {
        NODE_ENV  = 'test'
        BUILD_DIR = 'dist' 
        APP_NAME  = 'kijanikiosk-payments'
        NEXUS_URL = 'http://13.60.193.193:8081/repository/npm-kijanikiosk/'
        
        // We will populate these dynamically in the first stage
        PKG_VERSION = ''
        GIT_SHORT   = ''
        ARTIFACT_VERSION = ''
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
                    script {
                        // Dynamically compute version info inside the script block of the Build stage
                        env.PKG_VERSION = sh(script: "node -p \"require('./package.json').version\"", returnStdout: true).trim()
                        env.GIT_SHORT   = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                        env.ARTIFACT_VERSION = "${env.PKG_VERSION}-${env.GIT_SHORT}"
                    }

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
                    // Points cleanly to the subdirectory
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
                            
                            # === PHASE 2 TEST: VERIFY CREDENTIAL MASKING ===
                            echo "User: ${NEXUS_USER} Pass: ${NEXUS_PASS}"
                            # ===============================================

                            # Ensure we clean up .npmrc no matter what happens execution-wise
                            trap "rm -f .npmrc; echo '.npmrc cleaned up.'" EXIT
                            
                            # Clean up the Nexus URL protocol using shell sed for safety
                            NEXUS_PROTO_STRIP=$(echo "${NEXUS_URL}" | sed 's/http://')
                            
                            # Generate the Base64 token for Nexus auth
                            AUTH_TOKEN=$(printf "${NEXUS_USER}:${NEXUS_PASS}" | base64)
                            
                            # Configure local .npmrc for this project directory
                            echo "registry=${NEXUS_URL}" > .npmrc
                            echo "${NEXUS_PROTO_STRIP}:_auth=${AUTH_TOKEN}" >> .npmrc
                            echo "${NEXUS_PROTO_STRIP}:always-auth=true" >> .npmrc
                            
                            # Update package.json to match our exact ARTIFACT_VERSION
                            npm version ${ARTIFACT_VERSION} --no-git-tag-version
                            
                            # Push it to Nexus!
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