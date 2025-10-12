# EKS ALB/NLB Workshop 實作任務清單

## 1. 現有魚遊戲系統 Kubernetes 化

- [ ] 1.1 將現有 Docker Compose 轉換為 Kubernetes 配置
  - 基於現有的 client-service:8080 創建 Kubernetes Deployment 和 Service
  - 基於現有的 game-session-service:8082 創建 Kubernetes 配置
  - 基於現有的 game-server-service:8083 創建 Kubernetes 配置
  - 基於現有的 Redis:6379 創建 Kubernetes 配置
  - 保持現有的環境變數和配置結構
  - _需求: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ] 1.2 建立 Kubernetes 基礎資源配置
  - 創建 fish-game namespace
  - 建立 ConfigMap 包含現有的遊戲配置 (GAME_ROOM_MAX_PLAYERS, FISH_HIT_RATE 等)
  - 創建 Secret 包含 JWT_SECRET 和 Redis 連接資訊
  - 設置適當的資源限制和健康檢查 (使用現有的 /health 端點)
  - _需求: 1.1, 1.2_

- [ ] 1.3 驗證 Kubernetes 部署功能完整性
  - 測試 client-service 靜態文件服務和配置注入功能
  - 驗證 game-session-service 的用戶管理、大廳管理、配桌系統 API
  - 確認 game-server-service 的 WebSocket 通訊和遊戲邏輯功能
  - 測試管理後台功能 (兩個服務的 /admin 端點)
  - 驗證 Redis 數據存儲和統計功能
  - _需求: 1.1, 1.2, 1.3, 1.4, 1.5_

## 2. Workshop 基礎設施和環境準備

- [ ] 2.1 建立 Workshop 項目結構和文檔
  - 創建 Workshop 目錄結構 (docs/, examples/, scripts/, labs/)
  - 建立基於現有魚遊戲系統的 README.md 和學習指南
  - 創建學員手冊，說明現有系統的功能和架構
  - 製作講師指南，包含現有系統的演示步驟
  - _需求: 10.1, 10.2_

- [ ] 2.2 準備 EKS 集群和前置條件檢查
  - 創建 EKS 集群部署腳本和配置
  - 實作 AWS Load Balancer Controller 安裝腳本
  - 實作 External DNS 安裝和配置腳本
  - 建立前置條件檢查腳本 (基於補充資料的檢查命令)
  - 創建 IAM 權限檢查和配置腳本
  - _需求: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

## 3. 模組 1: 現有系統架構說明材料開發

- [ ] 3.1 創建現有系統功能分析文檔
  - 分析並文檔化 client-service 的靜態文件服務和配置注入功能
  - 詳細說明 game-session-service 的完整 API 功能 (用戶、錢包、大廳、配桌)
  - 分析 game-server-service 的 WebSocket 和遊戲邏輯功能
  - 說明兩個管理後台的功能和統計數據收集
  - _需求: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ] 3.2 建立 ALB/NLB 架構設計文檔
  - 基於補充資料創建 ALB 架構說明 (大廳+魚機配桌共用 ALB)
  - 說明多端口配置 (大廳: 80,443,8080,9380,9381,18080; 魚機配桌: 19380,19381)
  - 建立 NLB 架構說明 (魚機服務從端口 5001 開始)
  - 創建 HTTP Header 流量區分機制說明 (X-Service=lobby|fishmatch)
  - _需求: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ] 3.3 開發架構對比和遷移指南
  - 製作 Docker Compose vs EKS 架構對比圖表
  - 建立服務端口對應表 (8080→ALB, 8082→ALB, 8083→NLB)
  - 創建遷移步驟和注意事項文檔
  - 製作負載均衡器選擇決策指南
  - _需求: 1.1, 1.2, 1.3, 1.4, 1.5_

## 4. 模組 2: 基礎元件說明與驗證工具開發

- [ ] 4.1 實作基礎元件檢查腳本
  - 基於補充資料實作 AWS Load Balancer Controller 檢查腳本
  - 實作 External DNS 狀態檢查腳本
  - 建立現有 Ingress 和 Service 檢查腳本 (在 test namespace)
  - 創建元件狀態綜合報告工具
  - _需求: 2.1, 2.2, 2.3, 2.4_

- [ ] 4.2 建立權限確認工具
  - 實作 ServiceAccount 檢查腳本
  - 建立 RBAC 配置驗證工具 (ClusterRole 和 ClusterRoleBinding)
  - 創建 IAM 權限檢查工具 (如使用 IRSA)
  - 開發權限問題診斷和修復建議工具
  - _需求: 2.5, 2.6_

- [ ] 4.3 建立故障排除診斷工具
  - 實作常見問題自動診斷腳本
  - 建立子網標籤和安全組檢查工具
  - 創建 DNS 解析和網路連通性測試工具
  - 開發綜合健康檢查和報告生成工具
  - _需求: 8.4, 8.5, 8.6, 8.7_

## 5. 模組 3: ALB 實作配置和範例

- [ ] 5.1 建立基本 ALB Ingress 配置
  - 基於補充資料創建大廳 Ingress 配置 (lobby-ingress)
  - 實作多端口監聽配置 (80,443,8080,9380,9381,18080)
  - 建立 HTTP Header 條件路由 (X-Service=lobby)
  - 配置目標服務為現有的 game-session-service 和 client-service
  - _需求: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [ ] 5.2 實作 Canary 部署配置
  - 基於補充資料創建 Canary Deployment 配置
  - 實作 Canary Service 配置 (lobby-canary)
  - 建立 ALB 流量分割配置 (80% stable, 20% canary)
  - 開發 Canary 部署測試和驗證腳本
  - _需求: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [ ] 5.3 建立 ALB 實作實驗和測試
  - 創建逐步實作教學指南
  - 建立 ALB 功能驗證腳本 (測試多端口和 Header 路由)
  - 開發 Canary 部署演練腳本
  - 製作 ALB 故障排除指南
  - _需求: 9.1, 9.2, 10.4_

## 6. 模組 4: NLB 實作配置和範例

- [ ] 6.1 建立基本 NLB Service 配置
  - 基於補充資料創建 Fish Service NLB 配置
  - 實作多端口配置 (從 5001 開始)
  - 建立跨區域負載均衡配置
  - 配置目標服務為現有的 game-server-service (WebSocket 功能)
  - _需求: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [ ] 6.2 實作 Target Group Binding 配置
  - 基於補充資料創建 Target Group Binding 配置
  - 實作自定義健康檢查配置
  - 建立多魚機實例的 Target Group 管理
  - 開發 Target Group 狀態監控工具
  - _需求: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [ ] 6.3 實作 TCP 轉 TLS 配置
  - 基於補充資料創建 TLS 配置範例
  - 實作 SSL 證書綁定配置
  - 建立 TLS 端口配置 (5001 等)
  - 開發 TLS 連接測試和驗證工具
  - _需求: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [ ] 6.4 建立 NLB 實作實驗和測試
  - 創建逐步實作教學指南
  - 建立 NLB 功能驗證腳本 (測試 TCP/WebSocket 連接)
  - 開發多端口魚機服務演練腳本
  - 製作 NLB 故障排除指南
  - _需求: 9.3, 9.4, 10.4_

## 7. Workshop 交付和文檔

- [ ] 7.1 完善 Workshop 交付包
  - 整合所有基於現有魚遊戲系統的模組材料
  - 建立完整的 Docker Compose 到 EKS 遷移指南
  - 創建講師培訓材料和現有系統演示指南
  - 開發 Workshop 學員手冊和實作檢查清單
  - _需求: 10.1, 10.2, 10.3, 10.4_

- [ ] 7.2 建立配置模板和最佳實踐文檔
  - 創建基於現有系統的可重用 YAML 配置模板庫
  - 建立 ALB/NLB 配置最佳實踐指南
  - 開發故障排除手冊和常見問題解答
  - 製作 Workshop 維護和更新指南
  - _需求: 12.4, 12.6_