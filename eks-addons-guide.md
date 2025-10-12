# EKS Add-ons 安裝指南 - 電子捕魚機微服務系統

## 必要的 Add-ons

根據你的魚機微服務架構，以下 add-ons 是必須安裝的：

### 1. AWS Load Balancer Controller ⭐ **最重要**
**用途**: 支援 ALB 和 NLB 負載均衡器
**為什麼需要**: 你的架構需要 3 個 ALB (靜態資源、API、WebSocket)

```bash
# 安裝步驟已包含在 eks-setup-commands.sh 中
```

**驗證**:
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 2. EBS CSI Driver ⭐ **重要**
**用途**: 提供持久化存儲支援
**為什麼需要**: Redis 數據持久化、日誌存儲

**驗證**:
```bash
eksctl get addons --cluster myeks | grep ebs-csi-driver
```

### 3. CoreDNS ⭐ **必要**
**用途**: 集群內 DNS 解析
**為什麼需要**: 服務發現 (game-session-service, game-server-service)

**驗證**:
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

### 4. VPC CNI ⭐ **必要**
**用途**: 網路插件，提供 Pod 網路
**為什麼需要**: 基本網路功能

**驗證**:
```bash
kubectl get daemonset -n kube-system aws-node
```

### 5. kube-proxy ⭐ **必要**
**用途**: 網路代理，處理服務流量
**為什麼需要**: Service 和 Ingress 流量路由

**驗證**:
```bash
kubectl get daemonset -n kube-system kube-proxy
```

### 6. Metrics Server ⭐ **重要**
**用途**: 提供 CPU/記憶體指標
**為什麼需要**: HPA (水平自動擴展)、監控

**驗證**:
```bash
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```

## 可選的 Add-ons

### 7. Amazon EFS CSI Driver (可選)
**用途**: 共享文件系統
**何時需要**: 如果需要多個 Pod 共享文件

```bash
eksctl create addon --name aws-efs-csi-driver --cluster myeks
```

### 8. AWS for Fluent Bit (可選)
**用途**: 日誌收集到 CloudWatch
**何時需要**: 集中化日誌管理

```bash
eksctl create addon --name aws-for-fluent-bit --cluster myeks
```

### 9. Amazon VPC CNI Plugin for Kubernetes (進階配置)
**用途**: 進階網路功能
**何時需要**: 需要 Pod 安全組、前綴委派等功能

## 安裝順序

1. **基礎 Add-ons** (自動安裝): CoreDNS, VPC CNI, kube-proxy
2. **存儲 Add-ons**: EBS CSI Driver
3. **網路 Add-ons**: AWS Load Balancer Controller
4. **監控 Add-ons**: Metrics Server
5. **可選 Add-ons**: 根據需求安裝

## 驗證所有 Add-ons

```bash
# 檢查所有 add-ons 狀態
eksctl get addons --cluster myeks

# 檢查關鍵組件
kubectl get pods -n kube-system

# 檢查節點就緒狀態
kubectl get nodes

# 檢查 AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# 檢查 Metrics Server
kubectl top nodes
```

## 針對魚機系統的特殊配置

### ALB Ingress 準備
安裝完 AWS Load Balancer Controller 後，你可以建立 ALB Ingress：

```yaml
# alb-ingress-example.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fish-game-alb
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: game-session-service
            port:
              number: 8082
```

### HPA 準備
安裝完 Metrics Server 後，你可以設定自動擴展：

```yaml
# hpa-example.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: game-server-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: game-server-service
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## 故障排除

### AWS Load Balancer Controller 問題
```bash
# 檢查日誌
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# 檢查 IAM 權限
aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole
```

### Metrics Server 問題
```bash
# 檢查日誌
kubectl logs -n kube-system deployment/metrics-server

# 檢查 API 服務
kubectl get apiservice v1beta1.metrics.k8s.io
```

## 成本優化建議

1. **使用 Spot 實例**: 降低節點成本
2. **適當的實例大小**: t3.medium 適合開發，生產環境考慮 c5.large
3. **自動擴展**: 根據負載自動調整節點數量
4. **定期清理**: 移除不需要的資源和 add-ons

執行 `eks-setup-commands.sh` 腳本將會自動安裝所有必要的 add-ons！