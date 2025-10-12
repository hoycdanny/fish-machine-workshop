# 魚機遊戲 EKS Workshop 需求文檔

## 介紹

這是一個完整的魚機遊戲微服務系統從開發環境到 EKS 生產部署的 Workshop。整個流程包含：EC2 VS Code 開發環境設定、Docker Compose 本地驗證、ECR 映像管理、EKS 基礎設施部署、以及進階的 ALB/NLB 負載均衡配置。

系統基於現有的魚機遊戲微服務架構，包含客戶端服務、遊戲會話服務、遊戲伺服器服務和 Redis 數據庫，支援即時多人線上遊戲、WebSocket 通訊、用戶管理和錢包系統等核心功能。

## 需求

### 需求 0 - 開發環境設定

**User Story:** 作為開發者，我想要在 EC2 上設定完整的開發環境，這樣我就能在雲端進行標準化的開發工作

#### Acceptance Criteria

1. WHEN 使用者啟動 EC2 實例 THEN 系統 SHALL 提供預配置的 VS Code 開發環境
2. WHEN 使用者連接到 VS Code THEN 系統 SHALL 顯示完整的開發界面
3. WHEN 開發環境啟動 THEN 系統 SHALL 包含 Docker、AWS CLI、Git、kubectl 等必要工具
4. WHEN 使用者 git pull 專案 THEN 系統 SHALL 成功下載並顯示完整的專案結構
5. WHEN 環境設定完成 THEN 系統 SHALL 驗證所有工具的可用性

### 需求 1 - 服務驗證包含打包 Container 和 Compose 驗證，Push Image 到 ECR

**User Story:** 作為開發者，我想要驗證服務功能並將 Docker images 推送到 ECR，這樣我就能確保服務正常運作並準備好部署

#### Acceptance Criteria

1. WHEN 使用者執行 docker-compose up THEN 系統 SHALL 啟動所有服務並驗證功能
2. WHEN 服務驗證完成 THEN 系統 SHALL 確保所有服務間的連接正常
3. WHEN 使用者執行打包命令 THEN 系統 SHALL 建構所有服務的 Docker images
4. WHEN images 建構完成 THEN 系統 SHALL 自動推送到 ECR repositories
5. WHEN ECR push 完成 THEN 系統 SHALL 提供 image URIs 供後續部署使用

### 需求 2 - EKS 基礎設施部署安裝設定

**User Story:** 作為開發者，我想要部署 EKS 基礎設施，這樣我就能有一個可用的 Kubernetes 叢集來部署服務

#### Acceptance Criteria

1. WHEN 使用者執行 EKS 部署腳本 THEN 系統 SHALL 建立 EKS 叢集
2. WHEN EKS 叢集建立完成 THEN 系統 SHALL 配置必要的網路和安全群組
3. WHEN 基礎設施就緒 THEN 系統 SHALL 安裝必要的 Kubernetes 元件（如 ALB Controller、NLB）
4. WHEN 所有元件安裝完成 THEN 系統 SHALL 驗證叢集的可用性
5. WHEN 驗證完成 THEN 系統 SHALL 提供 kubectl 連接配置

### 需求 3 - 單一的 Docker Compose 移動到 EKS 後的服務架構說明

**User Story:** 作為開發者，我想要了解從 Docker Compose 到 EKS 的架構轉換，這樣我就能理解服務在 Kubernetes 中的運作方式

#### Acceptance Criteria

1. WHEN 使用者查看架構說明 THEN 系統 SHALL 提供 Docker Compose 與 EKS 的對比圖
2. WHEN 使用者需要了解服務對應 THEN 系統 SHALL 說明每個 Compose 服務如何轉換為 K8s 資源
3. WHEN 使用者查看網路架構 THEN 系統 SHALL 解釋服務發現和負載平衡的變化
4. WHEN 使用者需要了解儲存 THEN 系統 SHALL 說明 Redis 等有狀態服務的處理方式
5. WHEN 架構說明完整 THEN 系統 SHALL 提供最佳實踐建議

### 需求 4 - EKS 將剛剛打包的服務部署

**User Story:** 作為開發者，我想要將之前打包的服務部署到 EKS，這樣我就能在 Kubernetes 環境中運行完整的應用程式

#### Acceptance Criteria

1. WHEN 使用者執行部署命令 THEN 系統 SHALL 使用 ECR 中的 images 部署到 EKS
2. WHEN 服務部署開始 THEN 系統 SHALL 建立必要的 Deployments、Services 和 Ingress
3. WHEN 所有服務部署完成 THEN 系統 SHALL 驗證服務的健康狀態
4. WHEN 服務運行正常 THEN 系統 SHALL 提供外部訪問的 URL 或 IP
5. WHEN 部署完成 THEN 系統 SHALL 提供監控和日誌查看方式

### 需求 5 - ALB/NLB 進階負載均衡配置

**User Story:** 作為 DevOps 工程師，我希望能夠理解並配置進階的 ALB/NLB 功能，以便為魚遊戲系統提供企業級的負載均衡解決方案

#### Acceptance Criteria

1. WHEN 學員查看系統架構 THEN 系統 SHALL 清楚展示大廳和魚機配桌共用 ALB 的設計
2. WHEN 學員了解端口配置 THEN 系統 SHALL 說明實際服務端口配置 (Client: 8080, Session: 8082, Server: 8083)
3. WHEN 學員了解 ALB 設計 THEN 系統 SHALL 說明三個 ALB 分別處理靜態資源、API 和 WebSocket 流量
4. WHEN 學員了解 NLB 設計 THEN 系統 SHALL 說明 NLB 作為 WebSocket 的 TCP 直連備選方案
5. WHEN 學員查看流量區分 THEN 系統 SHALL 說明透過 HTTP header 區分不同服務流量的機制

### 需求 6 - Canary 部署和流量管理

**User Story:** 作為發布工程師，我希望能夠實作 Canary 部署配置，以便安全地發布新版本的魚遊戲服務

#### Acceptance Criteria

1. WHEN 部署 Canary 版本 THEN 系統 SHALL 創建獨立的 Deployment 和 Service
2. WHEN 配置流量分割 THEN 系統 SHALL 支援基於權重的流量分配 (例如 80% 穩定版本，20% Canary 版本)
3. WHEN 監控 Canary 部署 THEN 系統 SHALL 提供流量分配的即時監控
4. WHEN 回滾 Canary 部署 THEN 系統 SHALL 支援快速回滾到穩定版本
5. WHEN 推廣 Canary 版本 THEN 系統 SHALL 支援逐步增加 Canary 流量比例
6. WHEN 驗證 Canary 功能 THEN 系統 SHALL 確保 Canary 版本功能正常運作

### 需求 7 - NLB 和 TLS 配置

**User Story:** 作為網路工程師，我希望能夠實作 NLB Service 配置和 TLS 加密，以便為魚機服務提供安全的 TCP/TLS 負載均衡

#### Acceptance Criteria

1. WHEN 配置基本 NLB THEN 系統 SHALL 使用 Network Load Balancer 類型
2. WHEN 配置目標類型 THEN 系統 SHALL 使用 IP 目標類型以獲得最佳性能
3. WHEN 配置跨區域負載均衡 THEN 系統 SHALL 啟用跨可用區流量分配
4. WHEN 配置基本端口 THEN 系統 SHALL 支援 WebSocket 服務的 8083 端口
5. WHEN 配置 TLS 加密 THEN 系統 SHALL 使用 AWS Certificate Manager 的證書
6. WHEN 配置保留客戶端 IP THEN 系統 SHALL 保留原始客戶端 IP 地址

### 需求 8 - Target Group Binding 和進階配置

**User Story:** 作為高級 Kubernetes 工程師，我希望能夠使用 Target Group Binding 進行進階配置，以便實現更精細的流量控制

#### Acceptance Criteria

1. WHEN 創建 Target Group Binding THEN 系統 SHALL 直接綁定到 AWS Target Group
2. WHEN 配置自定義健康檢查 THEN 系統 SHALL 支援自定義健康檢查路徑和參數
3. WHEN 配置流量策略 THEN 系統 SHALL 支援不同的流量分配策略
4. WHEN 監控 Target Group THEN 系統 SHALL 提供 Target Group 健康狀態監控
5. WHEN 配置多個 Target Group THEN 系統 SHALL 支援一個服務綁定多個 Target Group
6. WHEN 更新 Target Group 配置 THEN 系統 SHALL 支援動態更新而不中斷服務

### 需求 9 - 監控和維運實務

**User Story:** 作為運維工程師，我希望能夠掌握維運操作實務，以便日常管理和維護 EKS 負載均衡器

#### Acceptance Criteria

1. WHEN 新增魚機服務 THEN 系統 SHALL 提供標準化的部署流程
2. WHEN 配置監控 THEN 系統 SHALL 設置 ALB/NLB 的 Access Log 到 S3
3. WHEN 監控指標 THEN 系統 SHALL 收集 Target Group 健康狀態、請求延遲、錯誤率等指標
4. WHEN 故障排除 THEN 系統 SHALL 提供常見問題的診斷和解決方法
5. WHEN 檢查健康狀態 THEN 系統 SHALL 提供健康檢查失敗的排查步驟
6. WHEN 檢查連線問題 THEN 系統 SHALL 提供連線超時和 DNS 解析問題的排查方法

### 需求 10 - 實際操作演練和學習成果

**User Story:** 作為學員，我希望能夠透過實際操作演練來鞏固學習成果，以便在實際工作中應用所學知識

#### Acceptance Criteria

1. WHEN 部署新魚機服務 THEN 學員 SHALL 能夠獨立完成從 Deployment 到 Service 到 NLB 的完整配置
2. WHEN 執行 Canary 部署 THEN 學員 SHALL 能夠配置流量分割並監控部署效果
3. WHEN 切換 TCP 到 TLS THEN 學員 SHALL 能夠為現有服務添加 TLS 加密
4. WHEN 模擬故障場景 THEN 學員 SHALL 能夠診斷和解決常見的負載均衡器問題
5. WHEN 優化性能 THEN 學員 SHALL 能夠調整負載均衡器配置以提升性能
6. WHEN 監控系統 THEN 學員 SHALL 能夠設置監控和告警機制

## 章節目錄結構

本 Workshop 將建立以下章節目錄：

- `0.dev-environment-setup/` - 開發環境設定
- `1.service-validation-and-ecr/` - 服務驗證包含打包 Container 和 Compose 驗證，Push Image 到 ECR
- `2.eks-infrastructure-deployment/` - EKS 基礎設施部署安裝設定
- `3.compose-to-eks-architecture/` - 單一的 Docker Compose 移動到 EKS 後的服務架構說明
- `4.eks-service-deployment/` - EKS 將剛剛打包的服務部署
- `5.alb-nlb-advanced-config/` - ALB/NLB 進階負載均衡配置
- `6.canary-deployment/` - Canary 部署和流量管理
- `7.nlb-tls-config/` - NLB 和 TLS 配置
- `8.target-group-binding/` - Target Group Binding 和進階配置
- `9.monitoring-operations/` - 監控和維運實務

每個目錄都包含該章節的詳細 README 和相關腳本檔案。

## 重要約束條件

**客戶服務程式碼不可修改** - 所有的配置、部署和整合都必須基於現有的服務程式碼，不能對應用程式邏輯進行任何修改。所有的環境配置、健康檢查、服務發現等都必須透過外部配置（環境變數、ConfigMap、Service 等）來實現。