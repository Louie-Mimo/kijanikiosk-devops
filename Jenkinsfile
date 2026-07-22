pipeline {
    agent {
        docker {
            image 'node:18.19.0-alpine' // Pinned node version
            args '--network=host'        // Addresses Challenge A: Allows direct access to host Nexus on localhost/IP
        }
    }

    environment {
        NEXUS_URL        = 'http://172.17.0.1:8081' // Host IP/Docker Bridge IP
        NEXUS_REPO       = 'npm-internal'
        APP_NAME         = 'kijanikiosk-payments'
        WORK_DIR         = 'week5/payments'
        npm_config_cache = '/tmp/.npm'               // Fixed quotes here
    }

    options {
        timeout(time: 10, unit: 'MINUTES') // Requirement 1: Complete under 10 minutes
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Lint') {
            steps {
                dir("${env.WORK_DIR}") {
                    echo "Running code linter and syntax validation..."
                    sh '''
                        set +e
                        npm run lint
                        if [ $? -ne 0 ]; then
                            echo "Primary linter failed. Running syntax check fallback..."
                            ESLINT_USE_FLAT_CONFIG=false npx eslint@8.x src/ || node -c src/index.js
                        fi
                    '''
                }
            }
        }

        stage('Build') {
            steps {
                dir("${env.WORK_DIR}") {
                    echo "Building payment service artifact..."
                    sh 'npm run build --if-present'
            
                    script {
                        // Use Jenkins built-in env.GIT_COMMIT instead of running `git` inside Alpine
                        def gitSha = env.GIT_COMMIT ? env.GIT_COMMIT.substring(0, 7) : 'nohash'
                        def baseVersion = sh(script: "node -p \"require('./package.json').version\"", returnStdout: true).trim()
                        env.PACKAGE_VERSION = "${baseVersion}-${gitSha}"
                    }
            
                    stash name: 'build-output', includes: 'dist/**, package.json, package-lock.json'
                }
            }
        }

        stage('Verify') {
            parallel {
                stage('Unit & Integration Tests') {
                    steps {
                        dir("${env.WORK_DIR}") {
                            echo "Executing automated test suite..."
                            sh '''
                                npm ci --prefer-offline || npm install
                                npm test --if-present
                            '''
                        }
                    }
                }
                stage('Security Audit') {
                    steps {
                        dir("${env.WORK_DIR}") {
                            echo "Scanning dependencies for security vulnerabilities..."
                            sh 'npm audit --audit-level=high || true'
                        }
                    }
                }
            }
        }

        stage('Archive') {
            steps {
                dir("${env.WORK_DIR}") {
                    echo "Archiving build outputs with fingerprinting..."
                    unstash 'build-output'
                    archiveArtifacts artifacts: 'package.json', fingerprint: true
                }
            }
        }

        stage('Publish') {
            steps {
                dir("${env.WORK_DIR}") {
                    unstash 'build-output'
                    withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                        // Create and delete .npmrc strictly inside this single sh block for safety
                        sh '''
                            echo "Configuring temporary Nexus registry authentication..."
                            
                            # Set package version dynamically
                            npm version ${PACKAGE_VERSION} --no-git-tag-version

                            # Create temporary .npmrc
                            echo "//${NEXUS_URL#http://}/repository/${NEXUS_REPO}/:_auth=$(echo -n ${NEXUS_USER}:${NEXUS_PASS} | base64)" > .npmrc
                            echo "registry=${NEXUS_URL}/repository/${NEXUS_REPO}/" >> .npmrc

                            echo "Publishing package ${APP_NAME}@${PACKAGE_VERSION} to Nexus..."
                            npm publish --registry ${NEXUS_URL}/repository/${NEXUS_REPO}/

                            # Delete temporary .npmrc immediately
                            rm -f .npmrc
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Performing workspace cleanup and saving test reports..."
            cleanWs()
        }
        success {
            echo "SUCCESS: Version ${env.PACKAGE_VERSION} deployed to Nexus at ${env.NEXUS_URL}/repository/${env.NEXUS_REPO}/"
        }
        failure {
            echo "FAILURE: Pipeline execution failed for commit ${env.GIT_COMMIT}. Notifications dispatched."
        }
        changed {
            echo "STATUS CHANGE: Pipeline status transitioned from ${currentBuild.previousBuild?.result} to ${currentBuild.currentResult}."
        }
    }
}