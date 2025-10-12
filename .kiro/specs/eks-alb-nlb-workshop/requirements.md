# EKS ALB/NLB Workshop 需求文檔

## 介紹

EKS ALB/NLB Workshop 是一個 4 小時的實作課程，專注於教授學員如何在 Amazon EKS 環境中配置和管理原生的 Application Load Balancer (ALB) 和 Network Load Balancer (NLB)。課程將基於現有的魚遊戲微服務系統，展示如何從 Docker Compose 環境遷移到 EKS，並實現複雜的負載均衡配置，包括多域名綁定、流量分割、Canary 部署等進階功能。

## 需求

### 需求 1

**用戶故事：** 作為 DevOps 工程師，我希望能夠理解現有魚遊戲系統的架構，以便為 EKS 遷移做好準備。

#### 驗收標準

1. WHEN 學員查看系統架構 THEN 系統 SHALL 清楚展示大廳和魚機配桌共用 ALB 的設計
2. WHEN 學員了解端口配置 THEN 系統 SHALL 說明大廳服務使用的多個端口 (80, 443, 8080, 9380, 9381, 18080)
3. WHEN 學員了解魚機配置 THEN 系統 SHALL 說明魚機配桌服務使用的端口 (19380, 19381)
4. WHEN 學員了解 NLB 設計 THEN 系統 SHALL 說明每個魚機對應一個端口從 5001 開始的架構
5. WHEN 學員查看流量區分 THEN 系統 SHALL 說明透過 HTTP header 區分不同服務流量的機制

### 需求 2

**用戶故事：** 作為系統管理員，我希望能夠驗證 EKS 集群中的基礎元件，以便確保 ALB/NLB 部署的前置條件。

#### 驗收標準

1. WHEN 檢查 AWS Load Balancer Controller THEN 系統 SHALL 確認控制器在 kube-system 命名空間中正常運行
2. WHEN 檢查 external-dns THEN 系統 SHALL 確認 DNS 自動管理服務正常運行
3. WHEN 檢查現有 Ingress THEN 系統 SHALL 顯示當前的 Ingress 配置狀態
4. WHEN 檢查現有 Service THEN 系統 SHALL 顯示當前的 Service 配置狀態
5. WHEN 檢查權限配置 THEN 系統 SHALL 確認 ServiceAccount 和 RBAC 配置正確
6. WHEN 檢查 IAM 權限 THEN 系統 SHALL 確認必要的 AWS 權限已正確配置

### 需求 3

**用戶故事：** 作為 Kubernetes 工程師，我希望能夠實作基本的 ALB Ingress 配置，以便為魚遊戲系統提供 HTTP/HTTPS 負載均衡。

#### 驗收標準

1. WHEN 配置大廳 Ingress THEN 系統 SHALL 支援多端口監聽 (80, 443, 8080, 9380, 9381, 18080)
2. WHEN 配置流量路由 THEN 系統 SHALL 透過 HTTP header 條件路由到正確的後端服務
3. WHEN 配置 SSL/TLS THEN 系統 SHALL 支援 HTTPS 流量和證書管理
4. WHEN 配置健康檢查 THEN 系統 SHALL 設置適當的健康檢查路徑和參數
5. WHEN 配置目標類型 THEN 系統 SHALL 使用 IP 模式以獲得最佳性能
6. WHEN 配置安全組 THEN 系統 SHALL 自動管理 ALB 相關的安全組規則

### 需求 4

**用戶故事：** 作為發布工程師，我希望能夠實作 Canary 部署配置，以便安全地發布新版本的魚遊戲服務。

#### 驗收標準

1. WHEN 部署 Canary 版本 THEN 系統 SHALL 創建獨立的 Deployment 和 Service
2. WHEN 配置流量分割 THEN 系統 SHALL 支援基於權重的流量分配 (例如 80% 穩定版本，20% Canary 版本)
3. WHEN 監控 Canary 部署 THEN 系統 SHALL 提供流量分配的即時監控
4. WHEN 回滾 Canary 部署 THEN 系統 SHALL 支援快速回滾到穩定版本
5. WHEN 推廣 Canary 版本 THEN 系統 SHALL 支援逐步增加 Canary 流量比例
6. WHEN 驗證 Canary 功能 THEN 系統 SHALL 確保 Canary 版本功能正常運作

### 需求 5

**用戶故事：** 作為網路工程師，我希望能夠實作 NLB Service 配置，以便為魚機服務提供 TCP/TLS 負載均衡。

#### 驗收標準

1. WHEN 配置基本 NLB THEN 系統 SHALL 使用 Network Load Balancer 類型
2. WHEN 配置目標類型 THEN 系統 SHALL 使用 IP 目標類型以獲得最佳性能
3. WHEN 配置跨區域負載均衡 THEN 系統 SHALL 啟用跨可用區流量分配
4. WHEN 配置多端口 THEN 系統 SHALL 支援從 5001 開始的多個魚機端口
5. WHEN 配置健康檢查 THEN 系統 SHALL 設置適當的 TCP 健康檢查
6. WHEN 配置保留客戶端 IP THEN 系統 SHALL 保留原始客戶端 IP 地址

### 需求 6

**用戶故事：** 作為高級 Kubernetes 工程師，我希望能夠使用 Target Group Binding 進行進階配置，以便實現更精細的流量控制。

#### 驗收標準

1. WHEN 創建 Target Group Binding THEN 系統 SHALL 直接綁定到 AWS Target Group
2. WHEN 配置自定義健康檢查 THEN 系統 SHALL 支援自定義健康檢查路徑和參數
3. WHEN 配置流量策略 THEN 系統 SHALL 支援不同的流量分配策略
4. WHEN 監控 Target Group THEN 系統 SHALL 提供 Target Group 健康狀態監控
5. WHEN 配置多個 Target Group THEN 系統 SHALL 支援一個服務綁定多個 Target Group
6. WHEN 更新 Target Group 配置 THEN 系統 SHALL 支援動態更新而不中斷服務

### 需求 7

**用戶故事：** 作為安全工程師，我希望能夠配置 TCP 轉 TLS 功能，以便為魚機服務提供加密通訊。

#### 驗收標準

1. WHEN 配置 SSL 證書 THEN 系統 SHALL 使用 AWS Certificate Manager 的證書
2. WHEN 配置 TLS 端口 THEN 系統 SHALL 指定哪些端口使用 TLS 加密
3. WHEN 配置 TLS 策略 THEN 系統 SHALL 使用安全的 TLS 版本和加密套件
4. WHEN 配置證書驗證 THEN 系統 SHALL 支援客戶端證書驗證 (可選)
5. WHEN 監控 TLS 連接 THEN 系統 SHALL 提供 TLS 連接的監控和日誌
6. WHEN 更新證書 THEN 系統 SHALL 支援證書的自動更新和輪換

### 需求 8

**用戶故事：** 作為運維工程師，我希望能夠掌握維運操作實務，以便日常管理和維護 EKS 負載均衡器。

#### 驗收標準

1. WHEN 新增魚機服務 THEN 系統 SHALL 提供標準化的部署流程
2. WHEN 配置監控 THEN 系統 SHALL 設置 ALB/NLB 的 Access Log 到 S3
3. WHEN 監控指標 THEN 系統 SHALL 收集 Target Group 健康狀態、請求延遲、錯誤率等指標
4. WHEN 故障排除 THEN 系統 SHALL 提供常見問題的診斷和解決方法
5. WHEN 檢查健康狀態 THEN 系統 SHALL 提供健康檢查失敗的排查步驟
6. WHEN 檢查連線問題 THEN 系統 SHALL 提供連線超時和 DNS 解析問題的排查方法
7. WHEN 檢查安全組 THEN 系統 SHALL 提供安全組配置檢查的方法

### 需求 9

**用戶故事：** 作為學員，我希望能夠透過實際操作演練來鞏固學習成果，以便在實際工作中應用所學知識。

#### 驗收標準

1. WHEN 部署新魚機服務 THEN 學員 SHALL 能夠獨立完成從 Deployment 到 Service 到 NLB 的完整配置
2. WHEN 執行 Canary 部署 THEN 學員 SHALL 能夠配置流量分割並監控部署效果
3. WHEN 切換 TCP 到 TLS THEN 學員 SHALL 能夠為現有服務添加 TLS 加密
4. WHEN 模擬故障場景 THEN 學員 SHALL 能夠診斷和解決常見的負載均衡器問題
5. WHEN 優化性能 THEN 學員 SHALL 能夠調整負載均衡器配置以提升性能
6. WHEN 監控系統 THEN 學員 SHALL 能夠設置監控和告警機制

### 需求 10

**用戶故事：** 作為培訓講師，我希望能夠提供完整的 workshop 材料和指導，以便學員能夠系統性地學習 EKS ALB/NLB 配置。

#### 驗收標準

1. WHEN 提供理論基礎 THEN 系統 SHALL 包含 ALB/NLB 的架構原理和最佳實踐
2. WHEN 提供實作步驟 THEN 系統 SHALL 包含詳細的操作指南和 YAML 配置範例
3. WHEN 提供故障排除 THEN 系統 SHALL 包含常見問題和解決方案的知識庫
4. WHEN 提供進階配置 THEN 系統 SHALL 包含複雜場景的配置範例和說明
5. WHEN 評估學習成果 THEN 系統 SHALL 提供實作檢查清單和驗證方法
6. WHEN 提供後續學習 THEN 系統 SHALL 提供進階主題和延伸學習資源

### 需求 11

**用戶故事：** 作為企業架構師，我希望 workshop 能夠涵蓋企業級的最佳實踐，以便學員能夠在生產環境中正確應用。

#### 驗收標準

1. WHEN 設計高可用架構 THEN 系統 SHALL 展示跨多個可用區的部署策略
2. WHEN 配置安全策略 THEN 系統 SHALL 包含網路安全和訪問控制的最佳實踐
3. WHEN 規劃容量 THEN 系統 SHALL 提供負載均衡器容量規劃的指導
4. WHEN 成本優化 THEN 系統 SHALL 說明如何優化 ALB/NLB 的成本
5. WHEN 合規要求 THEN 系統 SHALL 涵蓋日誌記錄和審計要求
6. WHEN 災難恢復 THEN 系統 SHALL 包含備份和災難恢復策略

### 需求 12

**用戶故事：** 作為 workshop 參與者，我希望能夠獲得實用的工具和腳本，以便在實際工作中提高效率。

#### 驗收標準

1. WHEN 提供自動化腳本 THEN 系統 SHALL 包含常用操作的自動化腳本
2. WHEN 提供監控工具 THEN 系統 SHALL 提供負載均衡器監控的工具和儀表板
3. WHEN 提供診斷工具 THEN 系統 SHALL 提供故障診斷的工具和檢查清單
4. WHEN 提供配置模板 THEN 系統 SHALL 提供可重用的 YAML 配置模板
5. WHEN 提供文檔模板 THEN 系統 SHALL 提供運維文檔的模板和範例
6. WHEN 提供最佳實踐 THEN 系統 SHALL 總結關鍵的最佳實踐和注意事項