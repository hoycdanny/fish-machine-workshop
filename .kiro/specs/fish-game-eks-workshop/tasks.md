# 魚機遊戲 EKS Workshop 實作任務清單

## 1. 建立章節目錄結構和基礎文件

- [ ] 1.1 建立 Workshop 目錄結構
  - 建立十個章節目錄（0-9）和對應的 README 文件
  - 建立每個章節的腳本檔案框架
  - 創建 Workshop 學員手冊和講師指南
  - 建立配置模板和範例文件庫
  - _Requirements: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9_

- [ ] 1.2 建立 Workshop 基礎設施文檔
  - 創建基於現有魚遊戲系統的 README.md 和學習指南
  - 建立現有系統功能分析和架構說明文檔
  - 製作 Docker Compose vs EKS 架構對比圖表
  - 創建完整的遷移步驟和注意事項文檔
  - _Requirements: 0, 1, 2, 3, 4_

## 2. Chapter 0: 開發環境設定實作

- [ ] 2.1 建立 EC2 環境設定腳本
  - 撰寫 EC2 實例配置和安全群組設定腳本
  - 實作 SSH 連接驗證功能
  - 建立 EC2 連接失敗診斷和修復工具
  - _Requirements: 0_

- [ ] 2.2 實作 VS Code Server 安裝和配置
  - 撰寫 VS Code Server 自動安裝腳本
  - 建立安全的配置檔案模板
  - 實作服務啟動和驗證功能
  - 建立 VS Code Server 故障排除工具
  - _Requirements: 0_

- [ ] 2.3 建立開發工具安裝腳本
  - 實作 Docker、AWS CLI、kubectl、eksctl 自動安裝
  - 建立工具版本驗證和相容性檢查
  - 撰寫環境變數配置腳本
  - 實作工具安裝失敗診斷和修復
  - _Requirements: 0_

- [ ] 2.4 實作 Git 專案管理功能
  - 建立 Git 認證配置腳本
  - 實作專案 clone 和同步功能
  - 撰寫專案結構驗證腳本
  - 建立 Git 操作故障排除工具
  - _Requirements: 0_

- [ ] 2.5 設定 AWS 權限和認證
  - 驗證 AWS 認證和登入功能
  - 設定 EKS、ECR、ALB 等後續會用到的權限
  - 建立 IAM 角色和政策驗證腳本
  - 實作權限問題診斷和修復建議工具
  - _Requirements: 0_

## 3. Chapter 1: 服務驗證和 ECR 推送實作

- [ ] 3.1 建立 Docker Compose 驗證腳本（不修改客戶程式碼）
  - 參考現在已經可以運行的 docker-compose.yaml
  - 建立端口可達性測試
  - 實作外部服務健康檢查功能
  - 撰寫服務日誌分析工具
  - _Requirements: 1_

- [ ] 3.2 實作 ECR 設定和認證
  - 建立 ECR repositories 自動建立腳本
  - 實作 AWS 認證和登入功能
  - 撰寫 ECR 權限驗證腳本
  - 建立 ECR 操作失敗診斷工具
  - _Requirements: 1_

- [ ] 3.3 建立 Docker 映像建構和推送腳本
  - 實作自動化建構流程（基於現有 Dockerfile）
  - 建立映像標籤管理功能
  - 撰寫推送狀態驗證和錯誤處理
  - 實作映像推送失敗診斷和重試機制
  - _Requirements: 1_

## 4. Chapter 2: EKS 基礎設施部署實作

- [ ] 4.1 建立 EKS 叢集設定腳本
  - 實作 EKS 叢集自動建立功能
  - 建立節點群組配置和管理
  - 撰寫叢集狀態驗證腳本
  - 實作 EKS 叢集建立失敗診斷工具
  - _Requirements: 2_

- [ ] 4.2 實作 EKS Add-ons 安裝
  - 建立 AWS Load Balancer Controller 安裝腳本
  - 實作 EBS CSI Driver 和其他必要 add-ons
  - 撰寫 add-ons 狀態監控和驗證
  - 建立 add-ons 安裝失敗診斷和修復工具
  - _Requirements: 2_

- [ ] 4.3 建立叢集驗證和故障排除工具
  - 實作節點健康檢查功能
  - 建立網路連接性測試
  - 撰寫常見問題自動診斷腳本
  - 建立綜合健康檢查和報告生成工具
  - _Requirements: 2_

## 5. Chapter 3: 架構說明文件建立

- [ ] 5.1 建立 Docker Compose 到 Kubernetes 對比文件
  - 撰寫架構對比圖表和說明
  - 建立服務對應關係表格
  - 實作互動式架構展示工具
  - 創建服務端口對應表和遷移指南
  - _Requirements: 3_

- [ ] 5.2 撰寫遷移指南和最佳實踐
  - 建立逐步遷移指導文件
  - 撰寫常見陷阱和解決方案
  - 實作配置轉換工具
  - 製作負載均衡器選擇決策指南
  - _Requirements: 3_

## 6. Chapter 4: EKS 服務部署實作

- [ ] 6.1 建立 Kubernetes 資源清單檔案（不修改客戶程式碼）
  - 撰寫 ConfigMap 和 Secret 配置
  - 建立 Deployment 清單（使用 TCP 探針）
  - 實作 Service 和 Ingress 配置
  - 建立基於現有系統的 Kubernetes 配置模板
  - _Requirements: 4_

- [ ] 6.2 實作服務部署自動化腳本
  - 建立部署順序管理功能
  - 實作滾動更新和回滾機制
  - 撰寫部署狀態監控工具
  - 建立部署失敗診斷和修復工具
  - _Requirements: 4_

- [ ] 6.3 建立服務驗證和監控工具
  - 實作外部連接性測試（不依賴程式碼內建端點）
  - 建立 ALB Ingress 狀態檢查
  - 撰寫效能和資源使用監控
  - 實作 Pod 啟動失敗診斷工具
  - _Requirements: 4_

## 7. Chapter 5: ALB/NLB 進階負載均衡配置實作

- [ ] 7.1 建立 Client Service ALB Ingress 配置
  - 基於現有系統創建 Client Service Ingress 配置 (client-ingress)
  - 實作靜態資源路由配置 (80,443 → 8080)
  - 配置目標服務為現有的 client-service (Port 8080)
  - 建立靜態文件服務的負載均衡配置
  - _Requirements: 5_

- [ ] 7.2 實作 Game Session Service ALB 配置
  - 創建 Game Session Service Ingress 配置 (session-ingress)
  - 實作 API 服務端口配置 (80,443 → 8082)
  - 配置目標服務為現有的 game-session-service (Port 8082)
  - 建立用戶管理、大廳、錢包 API 的負載均衡配置
  - _Requirements: 5_

- [ ] 7.3 實作 Game Server Service ALB 配置
  - 創建 Game Server Service Ingress 配置 (server-ingress)
  - 實作 WebSocket 服務端口配置 (80,443 → 8083)
  - 配置目標服務為現有的 game-server-service (Port 8083)
  - 建立 WebSocket 和遊戲邏輯的負載均衡配置
  - _Requirements: 5_

- [ ] 7.3 建立 ALB 功能驗證和測試工具
  - 創建 ALB 多端口和 Header 路由測試腳本
  - 建立 ALB 功能驗證腳本
  - 實作 ALB 配置錯誤診斷工具
  - 製作 ALB 故障排除指南
  - _Requirements: 5_

## 8. Chapter 6: Canary 部署和流量管理實作

- [ ] 8.1 實作 Canary 部署配置
  - 基於現有系統創建 Canary Deployment 配置
  - 實作 Canary Service 配置
  - 建立獨立的 Deployment 和 Service 資源
  - 配置 Canary 版本的環境變數和配置
  - _Requirements: 6_

- [ ] 8.2 建立流量分割配置
  - 實作 ALB 流量分割配置 (80% stable, 20% canary)
  - 建立基於權重的流量分配機制
  - 實作流量分割的即時監控
  - 建立流量比例動態調整功能
  - _Requirements: 6_

- [ ] 8.3 實作 Canary 部署管理工具
  - 建立 Canary 部署測試和驗證腳本
  - 實作快速回滾到穩定版本功能
  - 建立逐步增加 Canary 流量比例工具
  - 實作 Canary 部署監控和告警機制
  - _Requirements: 6_

## 9. Chapter 7: NLB 和 TLS 配置實作

- [ ] 9.1 建立基本 NLB Service 配置
  - 基於現有系統創建 Game Server NLB 配置
  - 實作 WebSocket TCP 直連端口配置 (8083)
  - 建立跨區域負載均衡配置
  - 配置目標服務為現有的 game-server-service (WebSocket 功能)
  - _Requirements: 7_

- [ ] 9.2 實作 TLS 加密配置
  - 建立 SSL 證書綁定配置
  - 實作 TLS 端口配置 (8083 TLS)
  - 建立 AWS Certificate Manager 整合
  - 實作 TLS 安全策略配置
  - _Requirements: 7_

- [ ] 9.3 建立 NLB 功能驗證和測試工具
  - 建立 NLB 功能驗證腳本 (測試 TCP/WebSocket 連接)
  - 開發 WebSocket 服務 TCP 直連演練腳本
  - 實作 TLS 連接測試和驗證工具
  - 製作 NLB 故障排除指南
  - _Requirements: 7_

## 10. Chapter 8: Target Group Binding 和進階配置實作

- [ ] 10.1 實作 Target Group Binding 配置
  - 建立 Target Group Binding 配置範例
  - 實作直接綁定到 AWS Target Group 功能
  - 建立多魚機實例的 Target Group 管理
  - 實作 Target Group 動態更新機制
  - _Requirements: 8_

- [ ] 10.2 建立自定義健康檢查配置
  - 實作自定義健康檢查路徑和參數配置
  - 建立不同流量分配策略配置
  - 實作一個服務綁定多個 Target Group 功能
  - 建立健康檢查失敗診斷工具
  - _Requirements: 8_

- [ ] 10.3 實作 Target Group 監控和管理工具
  - 建立 Target Group 健康狀態監控工具
  - 實作 Target Group 配置驗證腳本
  - 建立 Target Group 故障排除工具
  - 實作 Target Group 效能監控功能
  - _Requirements: 8_

## 11. Chapter 9: 監控和維運實務實作

- [ ] 11.1 建立監控和日誌配置
  - 實作 ALB/NLB 的 Access Log 到 S3 配置
  - 建立 Target Group 健康狀態、請求延遲、錯誤率等指標收集
  - 實作 CloudWatch 監控整合
  - 建立監控儀表板和告警配置
  - _Requirements: 9_

- [ ] 11.2 實作維運操作工具
  - 建立新增魚機服務的標準化部署流程
  - 實作服務擴展和縮減自動化腳本
  - 建立負載均衡器容量規劃工具
  - 實作成本優化分析和建議工具
  - _Requirements: 9_

- [ ] 11.3 建立故障排除和診斷工具
  - 實作常見問題的診斷和解決方法工具
  - 建立健康檢查失敗的排查步驟腳本
  - 實作連線超時和 DNS 解析問題的排查工具
  - 建立綜合故障診斷和自動修復機制
  - _Requirements: 9_

## 12. 實際操作演練和學習成果驗證

- [ ] 12.1 建立學員實作演練腳本
  - 創建部署新魚機服務的完整演練腳本
  - 建立 Canary 部署實作演練
  - 實作 TCP 到 TLS 切換演練
  - 建立故障模擬和排除演練
  - _Requirements: 10_

- [ ] 12.2 實作學員技能驗證工具
  - 建立學員操作能力自動化驗證系統
  - 實作實作檢查清單和評分機制
  - 建立故障排除技能測試
  - 實作最佳實踐應用檢查工具
  - _Requirements: 10_

- [ ] 12.3 建立 Workshop 成果評估系統
  - 實作完整工作流程自動化測試
  - 建立各章節間的整合驗證
  - 撰寫測試報告和結果分析工具
  - 建立學習成果追蹤和改進建議系統
  - _Requirements: 10_

## 13. 整合測試和文件完善

- [ ] 13.1 建立端到端測試套件
  - 實作完整 Workshop 流程自動化測試
  - 建立各章節間的整合驗證
  - 撰寫測試報告和結果分析工具
  - 實作 Workshop 品質保證機制
  - _Requirements: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10_

- [ ] 13.2 完善錯誤處理和故障排除
  - 實作全面的錯誤檢測和診斷
  - 建立自動修復機制
  - 撰寫故障排除指南和工具
  - 建立 Workshop 維護和更新指南
  - _Requirements: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10_

- [ ] 13.3 建立使用者指南和說明文件
  - 撰寫每個章節的詳細操作指南
  - 建立常見問題解答
  - 實作互動式幫助系統
  - 建立 Workshop 交付包和培訓材料
  - _Requirements: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10_

## 14. Workshop 交付和維護

- [ ] 14.1 完善 Workshop 交付包
  - 整合所有基於現有魚遊戲系統的模組材料
  - 建立完整的 Docker Compose 到 EKS 遷移指南
  - 創建講師培訓材料和現有系統演示指南
  - 開發 Workshop 學員手冊和實作檢查清單
  - _Requirements: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10_

- [ ] 14.2 建立配置模板和最佳實踐文檔
  - 創建基於現有系統的可重用 YAML 配置模板庫
  - 建立 ALB/NLB 配置最佳實踐指南
  - 開發故障排除手冊和常見問題解答
  - 製作 Workshop 維護和更新指南
  - _Requirements: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10_