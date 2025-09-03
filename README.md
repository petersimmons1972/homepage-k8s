# Homepage Kubernetes Deployment

This repository contains Kubernetes manifests for deploying [Homepage](https://gethomepage.dev/), a modern, fully static, fast, secure fully proxied, highly customizable application dashboard.

## 📋 Overview

Homepage is a modern dashboard that provides a clean interface to access all your homelab services and applications. This deployment includes:

- **Service Discovery**: Automatic Kubernetes service detection
- **Custom Widgets**: System monitoring and resource usage
- **Bookmarks**: Quick access to frequently used links
- **Themes**: Dark/light theme support with custom backgrounds
- **Security**: RBAC configuration for Kubernetes integration

## 🏗️ Architecture

```
Internet → Traefik Ingress → Homepage Dashboard → Kubernetes API
                ↓
        Service Discovery & Monitoring
```

## 📁 Project Structure

```
homepage/
├── README.md                    # This file
├── .gitignore                   # Git ignore rules
├── configmap.yaml               # Configuration (with placeholders)
├── configmap-template.yaml      # Template for secure deployment
├── deployment.yaml              # Homepage application deployment
├── service.yaml                 # Service definition
├── serviceaccount.yaml          # Service account for K8s access
├── clusterrole.yaml             # RBAC cluster role
├── clusterrolebinding.yaml      # RBAC binding
├── secret.yaml                  # Service account token
├── ingressroute.yaml            # Traefik ingress configuration
└── install_homepage.sh          # Installation script
```

## 🔐 Security Configuration

### Domain Configuration

**⚠️ IMPORTANT**: Replace domain placeholders before deployment.

#### Required Placeholders:

- `YOUR_HOMEPAGE_DOMAIN_HERE`: Your homepage domain
- `YOUR_TLS_SECRET_NAME`: TLS certificate secret name
- `YOUR_*_DOMAIN_HERE`: Various service domains

#### Secure Deployment Process:

```bash
# 1. Set your environment variables
export HOMEPAGE_DOMAIN="homepage.yourdomain.com"
export SEARCH_DOMAIN="https://search.yourdomain.com"
export RANCHER_DOMAIN="https://rancher.yourdomain.com"
export LINKWARDEN_DOMAIN="https://linkwarden.yourdomain.com"
export TRAEFIK_DOMAIN="https://traefik.yourdomain.com"
export OPENWEBUI_DOMAIN="https://openwebui.yourdomain.com"
export PROXMOX_DOMAIN="https://proxmox.yourdomain.com:8006"
export TRUENAS_DOMAIN="https://truenas.yourdomain.com"
export PIHOLE_1_IP="https://192.168.1.10"
export PIHOLE_2_IP="https://192.168.1.11"
export UNIFI_IP="https://192.168.1.1"

# 2. Create configuration from template
envsubst < configmap-template.yaml > configmap-production.yaml

# 3. Update ingress with your domain
sed -i 's/YOUR_HOMEPAGE_DOMAIN_HERE/'$HOMEPAGE_DOMAIN'/g' ingressroute.yaml
sed -i 's/YOUR_TLS_SECRET_NAME/your-tls-secret/g' ingressroute.yaml

# 4. Deploy the application
kubectl apply -f .

# 5. Clean up temporary files
rm configmap-production.yaml
```

## 🚀 Deployment Instructions

### Prerequisites

- Kubernetes cluster (1.19+)
- Traefik ingress controller
- cert-manager (for TLS certificates)
- RBAC enabled cluster

### Step 1: Configure Domains

1. Copy the template and configure your services:
```bash
cp configmap-template.yaml configmap-production.yaml
```

2. Edit `configmap-production.yaml` and replace environment variables with actual values
3. Update `ingressroute.yaml` with your domain and TLS secret

### Step 2: Deploy Homepage

```bash
# Apply all manifests
kubectl apply -f .

# Or use the installation script
chmod +x install_homepage.sh
./install_homepage.sh
```

### Step 3: Verify Deployment

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=homepage

# Check service
kubectl get svc homepage

# Check ingress
kubectl get ingress homepage

# View logs
kubectl logs -l app.kubernetes.io/name=homepage
```

## 🔧 Configuration

### Service Discovery

Homepage automatically discovers Kubernetes services using the configured service account and RBAC permissions.

### Widgets Configuration

Current widgets include:
- **Kubernetes Cluster**: CPU, memory, and node status
- **System Resources**: Host system monitoring
- **Search**: DuckDuckGo integration

### Bookmarks

Customize bookmarks in the ConfigMap:
- Developer tools and resources
- Work-related links (customize as needed)

### Services

Configure your homelab services in the services section:
- Homelab applications
- Infrastructure services
- External services

## 🛡️ Security Features

- **RBAC**: Minimal required permissions for Kubernetes API access
- **Service Account**: Dedicated service account with token-based auth
- **TLS**: HTTPS-only access via Traefik ingress
- **No Hardcoded Secrets**: Template-based configuration

## 🌐 Accessing Homepage

Once deployed, access your homepage at: `https://YOUR_HOMEPAGE_DOMAIN_HERE`

## 📊 Monitoring and Maintenance

### Health Checks

```bash
# Check application status
kubectl get pods -l app.kubernetes.io/name=homepage

# View application logs
kubectl logs -l app.kubernetes.io/name=homepage -f

# Check service endpoints
kubectl get endpoints homepage
```

### Configuration Updates

```bash
# Update configuration
kubectl edit configmap homepage

# Restart deployment to pick up changes
kubectl rollout restart deployment homepage
```

## 🔄 Customization

### Adding New Services

1. Edit the ConfigMap services section
2. Add your service with appropriate icon and URL
3. Apply the updated configuration

### Custom Themes

1. Modify the `custom.css` section in the ConfigMap
2. Add your custom styles
3. Restart the deployment

### Background Images

Update the background section in settings to change the dashboard background.

## 🐛 Troubleshooting

### Common Issues

1. **Pod not starting**: Check RBAC permissions and service account
2. **Service discovery not working**: Verify cluster role bindings
3. **Ingress not accessible**: Check domain DNS and TLS certificates
4. **Configuration not updating**: Restart deployment after ConfigMap changes

### Debug Commands

```bash
# Describe pod for detailed status
kubectl describe pod -l app.kubernetes.io/name=homepage

# Check RBAC permissions
kubectl auth can-i --list --as=system:serviceaccount:default:homepage

# Test service connectivity
kubectl port-forward svc/homepage 3000:3000
```

## 📚 References

- [Homepage Documentation](https://gethomepage.dev/)
- [Homepage GitHub](https://github.com/benphelps/homepage)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

## 📄 License

This deployment configuration is provided as-is for educational and production use.

---

**⚠️ Security Notice**: Always review and customize security settings for your specific environment before deploying to production.
