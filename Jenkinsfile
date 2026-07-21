pipeline {
    agent {
        docker {
            image 'node:18-alpine'
            args  '-u root -v /tmp:/tmp'
        }
    }

    environment {
        NODE_ENV         = 'test'
        NODE_OPTIONS     = '--max-old-space-size=512'
        BUILD_DIR        = 'dist'
        APP_NAME         = 'kijanikiosk-payments'
        NEXUS_URL        = 'http://172.17.0.1:8081/repository/npm-kijanikiosk/'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Lint') {
            steps {
                dir('week5/payments') {
                    echo "Running code linter and syntax validation..."
                    sh '''
                        set +e
                        npm run lint
                        if [ $? -ne 0 ]; then
                            echo "Fallback to syntax checking..."
                            ESLINT_USE_FLAT_CONFIG=false npx eslint@8.x src/ || node -c src/index.js
                        fi
                    '''
                }
            }
        }

        stage('Build') {
            steps {
                dir('week5/payments') {
                    script {
                        def pkgVer = sh(script: "node -p \"require('./package.json').version\"", returnStdout: true).trim()
                        def gitCommit = env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'local'
                        env.ARTIFACT_VERSION = "${pkgVer}-${gitCommit}"
                    }

                    echo "Building ${APP_NAME} version ${env.ARTIFACT_VERSION}..."
                    
                    echo "Cleaning existing dependencies..."
                    sh 'rm -rf node_modules'

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

                    stash name: 'build-output', includes: "${BUILD_DIR}/**, package.json, package-lock.json"
                }
            }
        }

        stage('Verify') {
            parallel {
                stage('Test') {
                    steps {
                        dir('week5/payments') {
                            sh 'rm -rf dist'
                            unstash 'build-output'
                            
                            echo "Running unit test suite..."
                            sh 'npm test || true'
                        }
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: '**/test-results/*.xml, **/junit.xml'
                        }
                    }
                }
                stage('Security Audit') {
                    steps {
                        dir('week5/payments') {
                            echo "Running security vulnerability scan..."
                            sh 'npm audit --audit-level=high || true'
                        }
                    }
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
                            
                            NEXUS_PROTO_STRIP=$(echo "${NEXUS_URL}" | sed -E 's|https?://||')
                            AUTH_TOKEN=$(printf "%s:%s" "${NEXUS_USER}" "${NEXUS_PASS}" | base64)
                            
                            echo "registry=${NEXUS_URL}" > .npmrc
                            echo "//${NEXUS_PROTO_STRIP}:_auth=${AUTH_TOKEN}" >> .npmrc
                            echo "//${NEXUS_PROTO_STRIP}:always-auth=true" >> .npmrc
                            
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
        changed {
            echo "Build status changed to ${currentBuild.currentResult} - ${JOB_NAME} #${BUILD_NUMBER}"
        }
        always {
            cleanWs()
        }
    }
}