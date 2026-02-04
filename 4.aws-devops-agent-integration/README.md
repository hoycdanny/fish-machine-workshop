# 第四章：AWS DevOps Agent 整合

> **從第三章銜接**：你已經完成了完整的應用部署，現在讓我們使用 AWS DevOps Agent 實現智能監控和自動化運維！

本章節展示如何使用 AWS DevOps Agent（AWS 原生服務）實現自動化監控、事件響應和部署管理。

## 🎯 核心特色

- ✅ **原生 AWS 整合**：直接整合 CloudWatch、ECR、EKS、GitHub/GitLab
- ✅ **自動事件響應**：自動檢測和響應生產事件
- ✅ **根因分析**：自動分析日誌、指標和部署歷史
- ✅ **持續改進**：分析歷史事件並提供改進建議
- ✅ **多工具整合**：支援 Datadog、New Relic、Splunk、ServiceNow、PagerDuty

## 📋 前置條件檢查

在開始第四章之前，請確保你已經完成前三章的所有步驟：

### ✅ 第0章：開發環境設置

```bash
# 檢查 AWS CLI 配置
aws sts get-caller-identity

# 預期輸出：顯示你的 AWS Account ID 和 User/Role
```

### ✅ 第1章：服務驗證與容器化

```bash
# 檢查 ECR 倉庫
aws ecr describe-repositories --region ap-northeast-2 --query 'repositories[?contains(repositoryName, `fish-game`)].repositoryName'

# 預期輸出：
# [
#     "fish-game-client",
#     "fish-game-session",
#     "fish-game-server"
# ]

# 檢查映像是否已推送
aws ecr list-images --repository-name fish-game-client --region ap-northeast-2
```

### ✅ 第2章：EKS 集群設置

```bash
# 檢查 EKS 集群
aws eks describe-cluster --name fish-game-cluster --region ap-northeast-2 --query 'cluster.status'

# 預期輸出：ACTIVE

# 檢查節點
kubectl get nodes

# 預期輸出：3 個 Ready 狀態的節點
```

### ✅ 第3章：EKS 服務部署

```bash
# 檢查部署狀態
kubectl get pods -n fish-game-system

# 預期輸出：所有 Pod 都是 Running 狀態

# 檢查負載均衡器
kubectl get ingress -n fish-game-system
kubectl get service game-server-nlb -n fish-game-system

# 預期輸出：ALB 和 NLB 都有外部地址
```

### 🏷️ 檢查資源標籤

**這是最重要的前置條件！** DevOps Agent 依賴標籤來發現和監控資源。

```bash
# 檢查所有章節的資源標籤
echo "🏷️  驗證資源標籤..."

# 第1章：ECR 倉庫標籤
aws ecr list-tags-for-resource \
  --resource-arn arn:aws:ecr:ap-northeast-2:$(aws sts get-caller-identity --query Account --output text):repository/fish-game-client \
  --query 'tags' --output table

# 第2章：EKS 集群標籤
aws eks describe-cluster \
  --name fish-game-cluster \
  --region ap-northeast-2 \
  --query 'cluster.tags'

# 第3章：Kubernetes 資源標籤
kubectl get namespace fish-game-system -o jsonpath='{.metadata.labels}' | jq '.'

# 第3章：負載均衡器標籤
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region ap-northeast-2 \
  --query "LoadBalancers[?contains(LoadBalancerName, 'fish-game')].LoadBalancerArn" \
  --output text | head -1)

if [ -n "$ALB_ARN" ]; then
  aws elbv2 describe-tags \
    --resource-arns $ALB_ARN \
    --query 'TagDescriptions[0].Tags[?Key==`Project` || Key==`Workshop` || Key==`ManagedBy`]' \
    --output table
fi
```

**預期標籤格式**：
```
Project=fish-machine-workshop
Workshop=fish-machine-workshop
ManagedBy=<chapter-script-path>
```

### 🚨 如果前置條件未滿足

如果任何檢查失敗，請返回相應章節完成設置：

- **第0章問題**：重新配置 AWS CLI 和 IAM 權限
- **第1章問題**：執行 `./build-and-push.sh` 推送映像
- **第2章問題**：執行 `./one-click-cmd.sh` 創建集群
- **第3章問題**：執行 `./deploy.sh` 部署服務
- **標籤問題**：返回各章節添加缺失的標籤

## 🚀 快速開始指南

### 方式一：使用 AWS Console（推薦新手）

這是最簡單的方式，適合第一次使用 DevOps Agent 的用戶。

#### 步驟 1：訪問 AWS DevOps Agent Console

```bash
# 在瀏覽器中打開
https://console.aws.amazon.com/devops-agent/

# 注意：DevOps Agent 目前僅在 us-east-1 區域可用
# 但可以監控其他區域的資源（如 ap-northeast-2）
```

#### 步驟 2：啟用 DevOps Agent

1. 點擊 "Get Started" 或 "Enable DevOps Agent"
2. 選擇 IAM 角色（自動創建或使用現有）
3. 確認權限並啟用服務

#### 步驟 3：配置資源發現

在 Console 中配置 DevOps Agent 發現你的資源：

1. **添加 EKS 集群**：
   - 導航到 "Capabilities" → "EKS Access"
   - 點擊 "Add EKS Cluster"
   - 選擇區域：`ap-northeast-2`
   - 選擇集群：`fish-game-cluster`
   - 添加標籤過濾：`Project=fish-machine-workshop`

2. **添加 CloudWatch 監控**：
   - 導航到 "Capabilities" → "Telemetry Sources"
   - 點擊 "Add CloudWatch"
   - 選擇區域：`ap-northeast-2`
   - 日誌群組：`/aws/eks/fish-game-cluster/*`
   - 添加標籤過濾：`Project=fish-machine-workshop`

3. **添加 ECR 監控**：
   - 導航到 "Capabilities" → "Container Registries"
   - 點擊 "Add ECR"
   - 選擇區域：`ap-northeast-2`
   - 倉庫前綴：`fish-game-*`
   - 添加標籤過濾：`Project=fish-machine-workshop`

#### 步驟 4：驗證配置

在 Console 中查看：
- "Topology" 頁面應該顯示你的應用架構圖
- "Resources" 頁面應該列出所有發現的資源
- "Investigations" 頁面準備好接收事件

### 方式二：使用 AWS CLI（適合自動化）

如果你熟悉命令行，可以使用 CLI 快速配置。

#### 步驟 1：安裝/更新 AWS CLI

```bash
# 檢查 AWS CLI 版本
aws --version

# 如果版本 < 2.15.0，需要更新
# macOS
brew upgrade awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update
```

#### 步驟 2：設置環境變數

```bash
# 設置區域和專案標籤
export AWS_REGION=us-east-1  # DevOps Agent 服務區域
export RESOURCE_REGION=ap-northeast-2  # 你的資源所在區域
export PROJECT_TAG="fish-machine-workshop"
export CLUSTER_NAME="fish-game-cluster"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "✅ 環境變數設置完成"
echo "   AWS Account: $AWS_ACCOUNT_ID"
echo "   DevOps Agent Region: $AWS_REGION"
echo "   Resource Region: $RESOURCE_REGION"
echo "   Project: $PROJECT_TAG"
```

#### 步驟 3：啟用 DevOps Agent

```bash
# 注意：以下命令是示例，實際 API 可能不同
# 請參考最新的 AWS 文檔

# 檢查 DevOps Agent 是否可用
aws devops-agent get-service-status --region $AWS_REGION 2>/dev/null || \
  echo "⚠️  DevOps Agent CLI 命令可能尚未可用，請使用 Console"

# 如果 CLI 可用，啟用服務
aws devops-agent enable-service \
  --region $AWS_REGION \
  --tags Key=Project,Value=$PROJECT_TAG
```

#### 步驟 4：配置資源監控

```bash
# 配置 EKS 監控
aws devops-agent register-resource \
  --resource-type eks-cluster \
  --resource-arn arn:aws:eks:$RESOURCE_REGION:$AWS_ACCOUNT_ID:cluster/$CLUSTER_NAME \
  --region $AWS_REGION \
  --tags Key=Project,Value=$PROJECT_TAG

# 配置 ECR 監控
for repo in fish-game-client fish-game-session fish-game-server; do
  aws devops-agent register-resource \
    --resource-type ecr-repository \
    --resource-arn arn:aws:ecr:$RESOURCE_REGION:$AWS_ACCOUNT_ID:repository/$repo \
    --region $AWS_REGION \
    --tags Key=Project,Value=$PROJECT_TAG
done

# 配置 CloudWatch 日誌監控
aws devops-agent register-resource \
  --resource-type cloudwatch-logs \
  --log-group-pattern "/aws/eks/$CLUSTER_NAME/*" \
  --region $AWS_REGION \
  --tags Key=Project,Value=$PROJECT_TAG
```

### 方式三：使用一鍵腳本（最快速）

我們提供了一個自動化腳本來完成所有配置。

#### 創建並執行腳本

```bash
# 創建腳本
cat > setup-devops-agent.sh << 'EOF'
#!/bin/bash
set -e

echo "🤖 開始配置 AWS DevOps Agent..."

# 環境變數
export AWS_REGION=us-east-1
export RESOURCE_REGION=ap-northeast-2
export PROJECT_TAG="fish-machine-workshop"
export CLUSTER_NAME="fish-game-cluster"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📋 配置資訊："
echo "   AWS Account: $AWS_ACCOUNT_ID"
echo "   Project: $PROJECT_TAG"
echo "   Cluster: $CLUSTER_NAME"
echo ""

# 檢查前置條件
echo "🔍 檢查前置條件..."

# 檢查 EKS 集群
if ! aws eks describe-cluster --name $CLUSTER_NAME --region $RESOURCE_REGION &>/dev/null; then
  echo "❌ EKS 集群不存在，請先完成第2章"
  exit 1
fi

# 檢查 ECR 倉庫
if ! aws ecr describe-repositories --region $RESOURCE_REGION --query 'repositories[?contains(repositoryName, `fish-game`)].repositoryName' --output text | grep -q fish-game; then
  echo "❌ ECR 倉庫不存在，請先完成第1章"
  exit 1
fi

# 檢查 Kubernetes 部署
if ! kubectl get namespace fish-game-system &>/dev/null; then
  echo "❌ Kubernetes 部署不存在，請先完成第3章"
  exit 1
fi

echo "✅ 前置條件檢查通過"
echo ""

# 提示用戶使用 Console
echo "⚠️  注意：AWS DevOps Agent 目前主要通過 Console 配置"
echo ""
echo "請按照以下步驟在 AWS Console 中配置："
echo ""
echo "1. 訪問：https://console.aws.amazon.com/devops-agent/"
echo "2. 啟用 DevOps Agent 服務"
echo "3. 添加以下資源："
echo ""
echo "   📦 EKS 集群："
echo "      - 區域: $RESOURCE_REGION"
echo "      - 集群: $CLUSTER_NAME"
echo "      - 標籤: Project=$PROJECT_TAG"
echo ""
echo "   📦 ECR 倉庫："
echo "      - 區域: $RESOURCE_REGION"
echo "      - 倉庫: fish-game-client, fish-game-session, fish-game-server"
echo "      - 標籤: Project=$PROJECT_TAG"
echo ""
echo "   📦 CloudWatch 日誌："
echo "      - 區域: $RESOURCE_REGION"
echo "      - 日誌群組: /aws/eks/$CLUSTER_NAME/*"
echo "      - 標籤: Project=$PROJECT_TAG"
echo ""

# 驗證資源標籤
echo "🏷️  驗證資源標籤..."
echo ""

# 檢查 EKS 標籤
echo "EKS 集群標籤："
aws eks describe-cluster --name $CLUSTER_NAME --region $RESOURCE_REGION --query 'cluster.tags' --output table

# 檢查 ECR 標籤
echo ""
echo "ECR 倉庫標籤："
for repo in fish-game-client fish-game-session fish-game-server; do
  echo "  $repo:"
  aws ecr list-tags-for-resource \
    --resource-arn arn:aws:ecr:$RESOURCE_REGION:$AWS_ACCOUNT_ID:repository/$repo \
    --query 'tags' --output table 2>/dev/null || echo "    未找到標籤"
done

# 檢查負載均衡器標籤
echo ""
echo "負載均衡器標籤："
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region $RESOURCE_REGION \
  --query "LoadBalancers[?contains(LoadBalancerName, 'fish-game')].LoadBalancerArn" \
  --output text | head -1)

if [ -n "$ALB_ARN" ]; then
  aws elbv2 describe-tags \
    --resource-arns $ALB_ARN \
    --query 'TagDescriptions[0].Tags[?Key==`Project` || Key==`Workshop` || Key==`ManagedBy`]' \
    --output table
fi

echo ""
echo "✅ 配置指南已顯示，請在 Console 中完成配置"
echo ""
echo "📚 詳細文檔：https://docs.aws.amazon.com/devops-agent/"

EOF

# 執行腳本
chmod +x setup-devops-agent.sh
./setup-devops-agent.sh
```

## 🎯 配置完成後的驗證

無論使用哪種方式，配置完成後請驗證：

### 1. 檢查資源拓撲

```bash
# 在 Console 中查看
# https://console.aws.amazon.com/devops-agent/topology

# 應該看到：
# - EKS Cluster: fish-game-cluster
# - ECR Repositories: fish-game-client, fish-game-session, fish-game-server
# - Kubernetes Resources: Deployments, Services, Ingress
# - Load Balancers: ALB x2, NLB x1
```

### 2. 檢查監控狀態

```bash
# 在 Console 中查看
# https://console.aws.amazon.com/devops-agent/monitoring

# 應該看到：
# - CloudWatch Logs 正在收集
# - EKS Events 正在監控
# - ECR Push Events 正在追蹤
```

### 3. 測試事件響應

創建一個測試事件來驗證 DevOps Agent 是否正常工作：

```bash
# 創建測試 CloudWatch 告警
aws cloudwatch put-metric-alarm \
  --alarm-name fish-game-test-alarm \
  --alarm-description "Test alarm for DevOps Agent" \
  --metric-name CPUUtilization \
  --namespace AWS/EKS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --region ap-northeast-2 \
  --tags Key=Project,Value=fish-machine-workshop

# 手動觸發告警（可選）
# 在 Console 中設置告警狀態為 ALARM

# 檢查 DevOps Agent 是否開始調查
# https://console.aws.amazon.com/devops-agent/investigations
```

## 📊 下一步：使用 DevOps Agent

配置完成後，你可以：

1. **監控部署**：查看 EKS 部署的實時狀態
2. **分析事件**：當告警觸發時查看自動調查結果
3. **獲取建議**：查看 DevOps Agent 提供的改進建議
4. **追蹤變更**：監控 ECR 映像推送和代碼變更

繼續閱讀下面的章節了解詳細功能。

---

## 🤖 什麼是 AWS DevOps Agent？

AWS DevOps Agent 是 AWS 在 2024 年 12 月推出的新服務（目前處於 Public Preview），它是一個自主運行的 "on-call engineer"，可以：

1. **監控基礎設施**：建立應用資源拓撲圖和關係
2. **自動調查事件**：當 CloudWatch 告警觸發時自動開始調查
3. **根因分析**：分析日誌、追蹤和代碼變更
4. **提供建議**：推薦緩解步驟或修復方案
5. **持續改進**：分析歷史事件模式並提供改進建議

### 支援的整合

**觀測性工具**：Amazon CloudWatch、Datadog、New Relic、Splunk、Dynatrace

**CI/CD 工具**：GitHub、GitLab

**票務和通訊**：ServiceNow、PagerDuty、Slack

**AWS 服務**：Amazon EKS、Amazon ECR、AWS CloudWatch、Multi-Account Access

## 🏷️ 資源標籤策略

### ManagedBy 標籤規範

`ManagedBy` 標籤應該指向創建該資源的腳本檔案路徑，方便除錯和追蹤：

```bash
# EC2 實例（由 User Data 創建）
Project=fish-machine-workshop
Workshop=fish-machine-workshop
ManagedBy=0.dev-environment-setup/ec2-userdata.sh

# ECR 倉庫（由 build script 創建）
Project=fish-machine-workshop
Workshop=fish-machine-workshop
ManagedBy=1.service-verification-containerization/build-and-push.sh

# EKS 集群（由 eksctl 創建）
Project=fish-machine-workshop
Workshop=fish-machine-workshop
ManagedBy=2.eks-cluster-setup/one-click-cmd.sh

# Kubernetes 資源（由 kubectl 創建）
Project=fish-machine-workshop
Workshop=fish-machine-workshop
ManagedBy=3.eks-service-deployment/deploy.sh
```

### 為什麼使用腳本路徑？

1. **除錯方便**：快速找到創建資源的腳本
2. **追蹤來源**：知道資源是如何創建的
3. **版本控制**：腳本在 Git 中有完整歷史
4. **自動化**：DevOps Agent 可以讀取腳本了解資源配置

## 🚀 設定 AWS DevOps Agent

### 步驟 1：啟用 AWS DevOps Agent

AWS DevOps Agent 目前處於 Public Preview，僅在 US East (N. Virginia) 區域可用。

```bash
# 設定 AWS 區域
export AWS_REGION=us-east-1

# 使用 AWS CLI 訪問 DevOps Agent
# 注意：需要最新版本的 AWS CLI
aws --version  # 確保版本 >= 2.x
```

### 步驟 2：配置 EKS 訪問

讓 DevOps Agent 能夠監控你的 EKS 集群：

```bash
# 配置 EKS 訪問能力
# DevOps Agent 會自動發現標記為 fish-machine-workshop 的 EKS 集群
aws devops-agent configure-capability \
  --capability-type eks-access \
  --cluster-name fish-game-cluster \
  --region ap-northeast-2 \
  --tags Project=fish-machine-workshop,Workshop=fish-machine-workshop
```

### 步驟 3：整合 CloudWatch

配置 CloudWatch 作為觀測性數據來源：

```bash
# 整合 CloudWatch
aws devops-agent configure-capability \
  --capability-type telemetry-source \
  --source-type cloudwatch \
  --region ap-northeast-2 \
  --log-groups "/aws/eks/fish-game-cluster/*" \
  --tags Project=fish-machine-workshop
```

### 步驟 4：整合 GitHub

連接你的 CI/CD 管道：

```bash
# 整合 GitHub
aws devops-agent configure-capability \
  --capability-type cicd-pipeline \
  --pipeline-type github \
  --repository-url https://github.com/hoycdanny/fish-machine-workshop \
  --tags Project=fish-machine-workshop
```

### 步驟 5：配置 Webhook（可選）

允許外部系統觸發 DevOps Agent 調查：

```bash
# 創建 Webhook
aws devops-agent create-webhook \
  --webhook-name fish-game-deployment-webhook \
  --description "Trigger investigation on ECR push" \
  --tags Project=fish-machine-workshop
```

## 🔍 AWS DevOps Agent 監控流程

### 自動監控架構

```
1. 建立拓撲圖
   ├─ EKS Cluster (fish-game-cluster)
   ├─ ECR Repositories (fish-game-*)
   ├─ CloudWatch Logs/Metrics
   └─ GitHub Repository

2. 持續監控
   ├─ CloudWatch Alarms
   ├─ EKS Pod Events
   ├─ ECR Image Pushes
   └─ Deployment Changes

3. 自動調查（當事件發生時）
   ├─ 分析日誌
   ├─ 檢查指標
   ├─ 追蹤代碼變更
   └─ 識別根因

4. 提供建議
   ├─ 緩解步驟
   ├─ 修復方案
   ├─ 改進建議
   └─ 最佳實踐
```

### DevOps Agent 自動發現的資源

AWS DevOps Agent 會自動發現並監控標記為 `Project=fish-machine-workshop` 的資源：

1. **EKS 集群**：Pod 狀態、Deployment 變更、Service 健康、Node 資源
2. **ECR 倉庫**：映像推送、映像掃描、標籤變化
3. **CloudWatch**：日誌分析、指標異常、告警觸發
4. **CI/CD 管道**：部署歷史、代碼變更、構建狀態

## 📊 使用 DevOps Agent 監控部署

### 場景 1：監控 ECR 映像推送

當你推送新的 Docker 映像到 ECR 時，DevOps Agent 會自動：

```bash
# 1. 推送映像
cd 1.service-verification-containerization
./build-and-push.sh v1.0.0

# 2. DevOps Agent 自動檢測
# - 記錄映像推送事件
# - 檢查映像掃描結果
# - 追蹤相關的代碼變更
# - 如果有告警，自動開始調查
```

### 場景 2：監控 EKS 部署

當你部署到 EKS 時，DevOps Agent 會自動：

```bash
# 1. 部署到 EKS
kubectl set image deployment/client-service \
  client-service=${ECR_REGISTRY}/fish-game-client:v1.0.0 \
  -n fish-game-system

# 2. DevOps Agent 自動監控
# - 追蹤 Deployment 變更
# - 監控 Pod 啟動狀態
# - 檢查健康檢查
# - 分析日誌錯誤
# - 如果失敗，提供根因分析
```

### 場景 3：自動事件響應

當 CloudWatch 告警觸發時：

```bash
# CloudWatch Alarm 觸發
# ↓
# DevOps Agent 自動開始調查
# ↓
# 1. 收集相關日誌
# 2. 分析指標趨勢
# 3. 檢查最近的部署
# 4. 識別代碼變更
# ↓
# 提供根因分析報告
# ↓
# 推薦修復步驟
```

## 🧪 測試 DevOps Agent

### 1. 創建測試告警

```bash
# 創建 CloudWatch 告警
aws cloudwatch put-metric-alarm \
  --alarm-name fish-game-high-error-rate \
  --alarm-description "High error rate in fish game" \
  --metric-name Errors \
  --namespace fish-game-system \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --tags Key=Project,Value=fish-machine-workshop
```

### 2. 觸發告警並觀察 DevOps Agent

```bash
# 查看 DevOps Agent 的調查結果
aws devops-agent list-investigations \
  --filter "tags.Project=fish-machine-workshop"

# 查看特定調查的詳情
aws devops-agent describe-investigation \
  --investigation-id <investigation-id>
```

### 3. 查看建議

```bash
# 查看 DevOps Agent 提供的改進建議
aws devops-agent list-recommendations \
  --filter "tags.Project=fish-machine-workshop"
```

## 📈 DevOps Agent 儀表板

AWS DevOps Agent 提供 Web 界面來查看：

1. **拓撲圖**：視覺化你的應用架構
2. **調查歷史**：所有自動調查的記錄
3. **建議列表**：改進建議和最佳實踐
4. **整合狀態**：所有工具的連接狀態

訪問：https://console.aws.amazon.com/devops-agent/

## 🎯 最佳實踐

### 1. 標籤管理

確保所有資源都有正確的標籤：

```bash
# 驗證資源標籤
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=fish-machine-workshop \
  --query 'ResourceTagMappingList[].[ResourceARN,Tags]' \
  --output table
```

### 2. 定期檢查建議

```bash
# 每週檢查 DevOps Agent 的建議
aws devops-agent list-recommendations \
  --filter "tags.Project=fish-machine-workshop" \
  --sort-by priority
```

### 3. 整合通知

配置 Slack 或 PagerDuty 接收 DevOps Agent 的通知：

```bash
# 整合 Slack
aws devops-agent configure-capability \
  --capability-type chat-integration \
  --integration-type slack \
  --webhook-url <your-slack-webhook>
```

## 🔧 故障排除

### DevOps Agent 無法訪問 EKS

確保 IAM 權限正確：

```bash
# 檢查 DevOps Agent 的 IAM 角色
aws iam get-role --role-name AWSDevOpsAgentRole

# 確保有 EKS 訪問權限
aws iam attach-role-policy \
  --role-name AWSDevOpsAgentRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

### DevOps Agent 未檢測到資源

確保資源有正確的標籤：

```bash
# 為 EKS 集群添加標籤
aws eks tag-resource \
  --resource-arn <cluster-arn> \
  --tags Project=fish-machine-workshop,Workshop=fish-machine-workshop
```

## 📚 相關文檔

- [AWS DevOps Agent 官方文檔](https://docs.aws.amazon.com/devopsagent/)
- [AWS DevOps Agent 功能頁面](https://aws.amazon.com/devops-agent/)
- [配置 DevOps Agent 能力](https://docs.aws.amazon.com/devopsagent/latest/userguide/configuring-capabilities-for-aws-devops-agent.html)

## 📋 完成檢查清單

- [ ] AWS DevOps Agent 已啟用
- [ ] EKS 訪問已配置
- [ ] CloudWatch 整合已完成
- [ ] GitHub/GitLab 整合已完成
- [ ] 所有資源都有正確的標籤
- [ ] 測試告警已創建並驗證
- [ ] DevOps Agent 儀表板可訪問
- [ ] 通知整合已配置（可選）

---

**🤖 使用 AWS 原生 DevOps Agent，讓你的運維更智能！**
