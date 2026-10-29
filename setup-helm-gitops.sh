set -euo pipefail

GITOPS_DIR="/mnt/c/Users/KUNALNAILWAL/source/mini-gitops-store-gitiops"
USERNAME="getGlitch"
CHART="$GITOPS_DIR/charts/mini-gitops-store"

cd "$GITOPS_DIR"
mkdir -p "$CHART/templates"

cat > "$CHART/Chart.yaml" <<'EOF'
apiVersion: v2
name: mini-gitops-store
description: Helm chart for Mini GitOps Store
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF

cat > "$CHART/values.yaml" <<EOF
replicaCount: 1
imagePullPolicy: Always

images:
  frontend: ghcr.io/$USERNAME/mini-gitops-store-frontend:latest
  product: ghcr.io/$USERNAME/mini-gitops-store-product-service:latest
  order: ghcr.io/$USERNAME/mini-gitops-store-order-service:latest
  inventory: ghcr.io/$USERNAME/mini-gitops-store-inventory-service:latest

ingress:
  enabled: true
  className: traefik
EOF

cat > "$CHART/templates/apps.yaml" <<'EOF'
{{- $root := . -}}
{{- range $app := list
  (dict "name" "frontend" "image" "frontend" "port" 80)
  (dict "name" "product-service" "image" "product" "port" 8081)
  (dict "name" "order-service" "image" "order" "port" 8082)
  (dict "name" "inventory-service" "image" "inventory" "port" 8083)
}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $app.name }}
spec:
  replicas: {{ $root.Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ $app.name }}
  template:
    metadata:
      labels:
        app: {{ $app.name }}
    spec:
      containers:
        - name: {{ $app.name }}
          image: {{ index $root.Values.images $app.image | quote }}
          imagePullPolicy: {{ $root.Values.imagePullPolicy }}
          ports:
            - containerPort: {{ $app.port }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $app.name }}
spec:
  selector:
    app: {{ $app.name }}
  ports:
    - port: {{ $app.port }}
      targetPort: {{ $app.port }}
{{- end }}
EOF

cat > "$CHART/templates/ingress.yaml" <<'EOF'
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mini-gitops-store
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
    - http:
        paths:
          - path: /api/products
            pathType: Prefix
            backend:
              service:
                name: product-service
                port:
                  number: 8081
          - path: /api/orders
            pathType: Prefix
            backend:
              service:
                name: order-service
                port:
                  number: 8082
          - path: /api/inventory
            pathType: Prefix
            backend:
              service:
                name: inventory-service
                port:
                  number: 8083
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
{{- end }}
EOF

cat > application.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mini-gitops-store
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/$USERNAME/mini-gitops-store-gitops.git
    targetRevision: main
    path: charts/mini-gitops-store
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: mini-gitops-store
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

helm lint "$CHART"
helm template mini-gitops-store "$CHART" >/dev/null

git add charts/mini-gitops-store application.yaml
git commit -m "feat: add Helm chart for Mini GitOps Store" || true
git push -u origin HEAD

echo "Helm chart validated and pushed."
