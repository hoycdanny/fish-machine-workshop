# 第二章：EKS 叢集設置

本目錄包含將魚機遊戲微服務部署到 Amazon EKS 的所有配置和腳本。

## 服務架構

基於第1部分的容器化服務，我們將部署以下服務到 EKS：

- **client-service** (Port 8081): 遊戲客戶端服務
- **game-session-service** (Port 8082): 遊戲會話管理服務  
- **game-server-service** (Port 8083): 遊戲伺服器服務
- **redis** (Port 6379): Redis 數據庫

## 部署步驟

1. **EKS 叢集創建**: 使用 `one-click-cmd.sh` 創建 EKS 叢集


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
![EKS 部署完成驗證](image/2.eks-deploy-done.PNG)
*圖 2.3：EKS 部署完成驗證，顯示所有服務和 Pod 的運行狀態*

2. 驗證叢集狀態：
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```


![EKS 集群創建過程](image/1.cluster-done.PNG)
*圖 2.1：EKS 集群創建過程，顯示 eksctl 創建集群的詳細步驟*

