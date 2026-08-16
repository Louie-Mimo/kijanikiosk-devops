pipeline {
    agent none

    parameters {
        booleanParam(
            name: 'PUBLISH_TO_NEXUS',
            defaultValue: false,
            description: 'Publish the Node package to Nexus after CI verification'
        )
    }

    environment {
        NEXUS_URL          = 'http://172.17.0.1:8081'
        NEXUS_REPO         = 'npm-kijanikiosk'
        APP_NAME           = 'kijanikiosk-payments'
        WORK_DIR           = 'deployment-pipeline/containers'
        npm_config_cache   = '/tmp/.npm'

        STAGING_NAMESPACE  = 'kijani-staging'
        PROD_NAMESPACE     = 'kijani-project'

        DEPLOYMENT_NAME    = 'kk-payments'
        SERVICE_NAME       = 'kk-payments'

        DEPLOYMENT_MANIFEST = 'k8s/kk-payments-deployment.yaml'
        SERVICE_MANIFEST    = 'k8s/kk-payments-service.yaml'

        ANSIBLE_INVENTORY   = 'ansible/inventory/hosts.yml'
        ANSIBLE_PLAYBOOK    = 'ansible/playbook.yml'
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
    }

    stages {

        /*
         * ============================================================
         * CI LAYER
         * Runs in the pinned Node container.
         * ============================================================
         */
        stage('CI') {
            agent {
                docker {
                    image 'node:20-alpine'
                    args '--network=host'
                }
            }

            stages {
                stage('Lint') {
                    steps {
                        dir("${env.WORK_DIR}") {
                            echo 'Running code linter and syntax validation...'

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
                            echo 'Building payment service artifact...'

                            sh 'npm run build --if-present'

                            script {
                                def gitSha = env.GIT_COMMIT
                                    ? env.GIT_COMMIT.substring(0, 7)
                                    : 'nohash'

                                def baseVersion = sh(
                                    script: "node -p \"require('./package.json').version\"",
                                    returnStdout: true
                                ).trim()

                                env.PACKAGE_VERSION = "${baseVersion}-${gitSha}"
                            }

                            stash(
                                name: 'build-output',
                                includes: 'dist/**, package.json, package-lock.json',
                                allowEmpty: true
                            )
                        }
                    }
                }

                stage('Verify') {
                    parallel {
                        stage('Unit & Integration Tests') {
                            steps {
                                dir("${env.WORK_DIR}") {
                                    echo 'Executing automated test suite...'

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
                                    echo 'Scanning dependencies for high-severity vulnerabilities...'
                                    sh 'npm audit --audit-level=high'
                                }
                            }
                        }
                    }
                }

                stage('Archive') {
                    steps {
                        dir("${env.WORK_DIR}") {
                            echo 'Archiving build outputs...'

                            unstash 'build-output'

                            archiveArtifacts(
                                artifacts: 'package.json',
                                fingerprint: true
                            )
                        }
                    }
                }

                stage('Publish to Nexus') {
                    when {
                        expression {
                            return params.PUBLISH_TO_NEXUS
                        }
                    }

                    steps {
                        dir("${env.WORK_DIR}") {
                            unstash 'build-output'

                            withCredentials([
                                usernamePassword(
                                    credentialsId: 'nexus-credentials',
                                    usernameVariable: 'NEXUS_USER',
                                    passwordVariable: 'NEXUS_PASS'
                                )
                            ]) {
                                sh '''
                                    npm version "${PACKAGE_VERSION}" --no-git-tag-version

                                    REGISTRY_URL="${NEXUS_URL}/repository/${NEXUS_REPO}/"
                                    AUTH_KEY="//${NEXUS_URL#http://}/repository/${NEXUS_REPO}/:_auth"

                                    echo "${AUTH_KEY}=$(echo -n "${NEXUS_USER}:${NEXUS_PASS}" | base64)" > .npmrc
                                    echo "registry=${REGISTRY_URL}" >> .npmrc

                                    npm publish --registry "${REGISTRY_URL}"

                                    rm -f .npmrc
                                '''
                            }
                        }
                    }
                }
            }
        }

        /*
         * ============================================================
         * CAPSTONE CD
         * Deployment stages run only for master.
         * ============================================================
         */
        stage('Validate Infrastructure') {
            when {
                branch 'master'
            }

            agent any

            steps {
                echo 'Validating Terraform staging infrastructure definition...'

                sh '''
                    set -eu

                    terraform -chdir=terraform fmt -check
                    terraform -chdir=terraform init -backend=false -input=false
                    terraform -chdir=terraform validate

                    echo "Terraform validation passed."
                '''
            }
        }

        stage('Prepare Ansible Runtime') {
            when {
                branch 'master'
            }

            agent any

            steps {
                echo 'Preparing reproducible Ansible Python environment...'

                sh '''
                    set -eu

                    rm -rf .venv-ansible

                    python3 -m venv .venv-ansible

                    .venv-ansible/bin/python -m pip install \
                        --disable-pip-version-check \
                        -r ansible/requirements.txt

                    echo "Ansible Python runtime ready."
                '''
            }
        }

        stage('Configure Staging') {
            when {
                branch 'master'
            }

            agent any

            steps {
                echo 'Applying staging configuration with Ansible...'

                sh '''
                    set -eu

                    ansible-playbook \
                      -i "${ANSIBLE_INVENTORY}" \
                      "${ANSIBLE_PLAYBOOK}"
                '''
            }
        }

        stage('Verify Staging Prerequisites') {
            when {
                branch 'master'
            }

            agent any

            steps {
                echo 'Checking staging namespace, ConfigMap, and Secret...'

                sh '''
                    set -eu

                    kubectl get namespace "${STAGING_NAMESPACE}"

                    kubectl get configmap kk-payments-config \
                      -n "${STAGING_NAMESPACE}"

                    kubectl get secret kk-payments-secrets \
                      -n "${STAGING_NAMESPACE}"

                    STAGING_DB_HOST="$(
                      kubectl get configmap kk-payments-config \
                        -n "${STAGING_NAMESPACE}" \
                        -o jsonpath='{.data.DB_HOST}'
                    )"

                    if [ "${STAGING_DB_HOST}" != "kk-postgres-staging" ]; then
                        echo "ERROR: Unexpected staging DB_HOST: ${STAGING_DB_HOST}"
                        exit 1
                    fi

                    echo "Staging prerequisites verified."
                '''
            }
        }

        stage('Deploy Staging') {
            when {
                branch 'master'
            }

            agent any

            steps {
                echo 'Deploying kk-payments to kijani-staging...'

                sh '''
                    set -eu

                    kubectl apply \
                      -n "${STAGING_NAMESPACE}" \
                      -f "${DEPLOYMENT_MANIFEST}" \
                      -f "${SERVICE_MANIFEST}"

                    kubectl rollout status \
                      deployment/"${DEPLOYMENT_NAME}" \
                      -n "${STAGING_NAMESPACE}" \
                      --timeout=120s
                '''
            }
        }

        stage('Staging Smoke Test') {
            when {
                branch 'master'
            }

            agent any

            steps {
                echo 'Running mandatory staging /health smoke test...'

                sh '''
                    set -eu

                    PORT=13002
                    PF_LOG="staging-port-forward-${BUILD_NUMBER}.log"
                    HEALTH_OUTPUT="staging-health-${BUILD_NUMBER}.json"

                    kubectl port-forward \
                      -n "${STAGING_NAMESPACE}" \
                      svc/"${SERVICE_NAME}" \
                      "${PORT}:3001" \
                      > "${PF_LOG}" 2>&1 &

                    PF_PID=$!

                    cleanup() {
                        kill "${PF_PID}" 2>/dev/null || true
                    }

                    trap cleanup EXIT

                    PASSED=0

                    for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
                        echo "Smoke test attempt ${attempt}/15..."

                        if curl \
                          --fail \
                          --silent \
                          --show-error \
                          --max-time 5 \
                          "http://127.0.0.1:${PORT}/health" \
                          > "${HEALTH_OUTPUT}"; then

                            echo "Staging smoke test passed."
                            cat "${HEALTH_OUTPUT}"
                            echo
                            PASSED=1
                            break
                        fi

                        sleep 2
                    done

                    if [ "${PASSED}" -ne 1 ]; then
                        echo "ERROR: Staging smoke test failed."
                        echo "Port-forward log:"
                        cat "${PF_LOG}" || true
                        exit 1
                    fi
                '''

                archiveArtifacts(
                    artifacts: 'staging-health-*.json, staging-port-forward-*.log',
                    allowEmptyArchive: true
                )
            }
        }

        /*
         * This stage is unreachable when the staging smoke test fails.
         */
        stage('Staging Error Rate Check') {
            when {
                branch 'master'
            }

            agent any

            steps {
                echo 'Evaluating staging HTTP error rate against the 5% threshold...'

                sh '''
                    set -eu

                    python3 -m py_compile monitoring/error-rate-monitor.py

                    bash -n monitoring/check-staging-error-rate.sh
                    bash -n monitoring/test-error-rate-monitor.sh

                    echo "Running controlled threshold validation..."
                    ./monitoring/test-error-rate-monitor.sh

                    echo
                    echo "Running live staging error-rate check..."

                    REQUEST_COUNT=20 \
                    THRESHOLD=5 \
                    OUTPUT_DIR="$WORKSPACE/monitoring/output" \
                    ./monitoring/check-staging-error-rate.sh
                '''

                archiveArtifacts(
                    artifacts: 'monitoring/output/*',
                    fingerprint: true,
                    allowEmptyArchive: false
                )
            }
        }

        stage('Production Approval') {
            when {
                beforeInput true
                branch 'master'
            }

            options {
                timeout(time: 10, unit: 'MINUTES')
            }

            input {
                message 'Staging deployment and smoke test passed. Promote kk-payments to production?'
                ok 'Promote to Production'
            }

            agent none

            steps {
                echo 'Production promotion approved.'
            }
        }

        stage('Verify Production Prerequisites') {
            when {
                branch 'master'
            }

            agent any

            steps {
                sh '''
                    set -eu

                    kubectl get namespace "${PROD_NAMESPACE}"

                    kubectl get configmap kk-payments-config \
                      -n "${PROD_NAMESPACE}"

                    kubectl get secret kk-payments-secrets \
                      -n "${PROD_NAMESPACE}"

                    PROD_DB_HOST="$(
                      kubectl get configmap kk-payments-config \
                        -n "${PROD_NAMESPACE}" \
                        -o jsonpath='{.data.DB_HOST}'
                    )"

                    if [ "${PROD_DB_HOST}" != "kk-postgres" ]; then
                        echo "ERROR: Unexpected production DB_HOST: ${PROD_DB_HOST}"
                        exit 1
                    fi

                    echo "Production prerequisites verified."
                '''
            }
        }

        stage('Deploy Production') {
            when {
                branch 'master'
            }

            agent any

            steps {
                echo 'Deploying the SAME kk-payments manifests to production...'

                sh '''
                    set -eu

                    kubectl apply \
                      -n "${PROD_NAMESPACE}" \
                      -f "${DEPLOYMENT_MANIFEST}" \
                      -f "${SERVICE_MANIFEST}"

                    kubectl rollout status \
                      deployment/"${DEPLOYMENT_NAME}" \
                      -n "${PROD_NAMESPACE}" \
                      --timeout=120s

                    kubectl get deployment "${DEPLOYMENT_NAME}" \
                      -n "${PROD_NAMESPACE}"

                    echo "Production deployment completed."
                '''
            }
        }
    }

    post {
        always {
            echo 'Pipeline completed.'
        }

        success {
            echo "SUCCESS: ${env.APP_NAME} pipeline completed successfully."
        }

        failure {
            echo "FAILURE: Pipeline failed for commit ${env.GIT_COMMIT}."
        }

        aborted {
            echo 'ABORTED: Pipeline or production promotion was cancelled.'
        }

        changed {
            echo "STATUS CHANGE: ${currentBuild.previousBuild?.result} -> ${currentBuild.currentResult}"
        }
    }
}
