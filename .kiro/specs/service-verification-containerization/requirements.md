# 服務驗證和容器化需求文檔

## 簡介

本階段的目標是驗證現有的魚機遊戲微服務功能，並將它們容器化準備部署到 EKS。這是從開發環境到生產部署的關鍵步驟。

## 需求

### 需求 1: 開發環境訪問

**用戶故事:** 作為 Workshop 參與者，我希望能夠訪問 VS Code Server 開發環境，並且 AWS 權限已經自動配置好，以便直接進行後續的開發和部署工作。

#### 驗收標準

1. WHEN 參與者嘗試訪問 VS Code Server THEN 系統 SHALL 提供可訪問的 URL 和正確的認證方式
2. WHEN 參與者成功登入 VS Code Server THEN 系統 SHALL 顯示完整的專案結構和已安裝的擴展
3. WHEN 參與者執行 AWS CLI 命令 THEN 系統 SHALL 自動使用 EC2 IAM Role 提供 AWS 權限
4. WHEN 參與者執行 `aws sts get-caller-identity` THEN 系統 SHALL 顯示正確的 AWS 帳戶和角色資訊

### 需求 2: 現有服務驗證

**用戶故事:** 作為開發者，我希望驗證現有的三個微服務（client-service、game-session-service、game-server-service）能夠正常運行，以便確保容器化前的功能完整性。

#### 驗收標準

1. WHEN 啟動 client-service THEN 服務 SHALL 在端口 8080 上正常運行並響應健康檢查
2. WHEN 啟動 game-session-service THEN 服務 SHALL 在端口 8082 上正常運行並能夠處理會話請求
3. WHEN 啟動 game-server-service THEN 服務 SHALL 在端口 8083 上正常運行並能夠處理 WebSocket 連接
4. WHEN 所有服務同時運行 THEN 系統 SHALL 能夠完成端到端的遊戲流程測試

### 需求 3: Docker 容器化

**用戶故事:** 作為 DevOps 工程師，我希望將每個微服務打包成 Docker 容器，以便在 Kubernetes 環境中部署。

#### 驗收標準

1. WHEN 為每個服務創建 Dockerfile THEN 容器 SHALL 能夠成功構建且大小合理（< 500MB）
2. WHEN 運行容器化的服務 THEN 容器 SHALL 在相同端口上提供與原生服務相同的功能
3. WHEN 使用 Docker Compose 編排服務 THEN 所有服務 SHALL 能夠相互通信並正常工作
4. WHEN 容器啟動 THEN 服務 SHALL 在 30 秒內達到就緒狀態

### 需求 4: ECR 準備

**用戶故事:** 作為雲端工程師，我希望準備 AWS ECR 倉庫並推送容器映像，以便 EKS 叢集能夠拉取和部署服務。

#### 驗收標準

1. WHEN 創建 ECR 倉庫 THEN 系統 SHALL 為每個服務創建獨立的倉庫
2. WHEN 推送容器映像到 ECR THEN 映像 SHALL 成功上傳並可被 EKS 訪問
3. WHEN 標記容器映像 THEN 系統 SHALL 使用語義化版本標籤（如 v1.0.0）
4. WHEN 驗證 ECR 映像 THEN 系統 SHALL 能夠從 ECR 成功拉取並運行容器

### 需求 5: 本地測試環境

**用戶故事:** 作為測試工程師，我希望建立一個本地測試環境，以便在部署到 EKS 前驗證所有服務的整合功能。

#### 驗收標準

1. WHEN 使用 Docker Compose 啟動所有服務 THEN 系統 SHALL 模擬生產環境的網路拓撲
2. WHEN 執行整合測試 THEN 系統 SHALL 驗證服務間的 API 通信正常
3. WHEN 測試 WebSocket 連接 THEN 系統 SHALL 確保實時通信功能正常
4. WHEN 進行負載測試 THEN 系統 SHALL 能夠處理預期的並發用戶數量

### 需求 6: 文檔和腳本

**用戶故事:** 作為 Workshop 參與者，我希望有清晰的文檔和自動化腳本，以便快速理解和執行每個步驟。

#### 驗收標準

1. WHEN 查看服務文檔 THEN 文檔 SHALL 包含每個服務的 API 規格和配置說明
2. WHEN 執行構建腳本 THEN 腳本 SHALL 自動化容器構建和標籤過程
3. WHEN 執行部署腳本 THEN 腳本 SHALL 自動化 ECR 推送和驗證過程
4. WHEN 遇到問題 THEN 文檔 SHALL 提供故障排除指南和常見問題解答