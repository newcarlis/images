#!/usr/bin/env bash

set -o errexit -o nounset -o errtrace -o pipefail -x

TMPDIR="$(mktemp -d)"

cat <<EOF > "${TMPDIR}/ns.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: ${NS}
EOF

apk add curl
curl -sSL -o "${TMPDIR}/sample.war" "${WAR_URL}"

kubectl apply -f "${TMPDIR}/ns.yaml"

kubectl create configmap sample-war-configmap -n ${NS} --from-file=sample.war=${TMPDIR}/sample.war

cat <<EOF > "${TMPDIR}/deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tomcat-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tomcat
  template:
    metadata:
      labels:
        app: tomcat
    spec:
      containers:
      - name: tomcat
        image: ${IMAGE_NAME}
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: sample-war
          mountPath: /usr/local/tomcat/webapps/sample.war
          subPath: sample.war
      volumes:
      - name: sample-war
        configMap:
          name: sample-war-configmap
          items:
          - key: sample.war
            path: sample.war

EOF

kubectl apply -f "${TMPDIR}/deployment.yaml" -n ${NS}

# Wait for the deployment to be ready
kubectl rollout status deployment/tomcat-deployment -n ${NS} --timeout=300s

# Port forward to the deployment
kubectl port-forward deployment/tomcat-deployment -n ${NS} 8080:8080 &

pid=$!
echo "Port-forward PID: $pid"
trap "echo 'Killing port-forward'; kill $pid" EXIT

sleep 10
curl localhost:8080/sample/ | grep "Hello"
