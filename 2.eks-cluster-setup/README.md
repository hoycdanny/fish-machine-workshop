# EKS 叢集設置

本目錄包含將魚機遊戲微服務部署到 Amazon EKS 的所有配置和腳本。

## 服務架構

基於第1部分的容器化服務，我們將部署以下服務到 EKS：

- **client-service** (Port 8081): 遊戲客戶端服務
- **game-session-service** (Port 8082): 遊戲會話管理服務  
- **game-server-service** (Port 8083): 遊戲伺服器服務
- **redis** (Port 6379): Redis 數據庫

## 部署步驟

1. **EKS 叢集創建**: 使用 `one-click-cmd.sh` 創建 EKS 叢集
2. **Kubernetes 配置**: 應用 `k8s-manifests/` 中的配置文件
3. **服務驗證**: 驗證所有服務正常運行

## 文件結構

```
2.eks-cluster-setup/
├── README.md                 # 本文件
├── one-click-cmd.sh          # EKS 叢集一鍵部署腳本
├── k8s-manifests/            # Kubernetes 配置文件
│   ├── namespace.yaml        # 命名空間
│   ├── configmap.yaml        # 配置映射
│   ├── redis-deployment.yaml # Redis 部署
│   ├── client-deployment.yaml # 客戶端服務部署
│   ├── session-deployment.yaml # 會話服務部署
│   ├── server-deployment.yaml # 伺服器服務部署
│   ├── services.yaml         # 服務配置
│   └── ingress.yaml          # Ingress 配置
└── scripts/                  # 輔助腳本
    ├── deploy-services.sh    # 部署服務腳本
    └── verify-deployment.sh  # 驗證部署腳本
```

## 前置條件

- AWS CLI 已配置
- kubectl 已安裝
- eksctl 已安裝
- Docker 映像已推送到 ECR（來自第1部分）

## 使用方法

1. 執行一鍵部署腳本：
   ```bash
   ./one-click-cmd.sh
   ```

2. 驗證部署：
   ```bash
   ./scripts/verify-deployment.sh
   ```