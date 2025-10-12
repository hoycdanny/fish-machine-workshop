# 🚀 Chapter 2: EKS 集群建立

> **AWS EKS 集群部署 + Load Balancer + 必要附加組件**

本章節將建立一個完整的 EKS 集群，為魚機遊戲微服務提供 Kubernetes 運行環境。

## 🎯 本章目標

- ✅ **EKS 集群建立**：使用 eksctl 快速建立集群
- ✅ **Load Balancer Controller**：支援 ALB/NLB
- ✅ **EBS CSI Driver**：持久化儲存支援
- ✅ **Metrics Server**：資源監控
- ✅ **核心附加組件**：CoreDNS、VPC CNI、Kube-proxy

## 🚀 CloudShell 部署 (推薦)

### 1. 開啟 AWS CloudShell
```bash
# 在 AWS Console 中點擊 CloudShell 圖標
# 或直接訪問: https://console.aws.amazon.com/cloudshell/
```

### 2. Clone 專案並部署
```bash
# Clone 專案
git clone https://github.com/hoycdanny/fish-machine-workshop.git
cd fish-game-eks-workshop/2.eks-cluster-setup

# 執行一鍵部署 (約需 15-20 分鐘)
chmod +x one-click-cmd.sh
./one-click-cmd.sh
```

### 3. CloudShell 優勢
- ✅ **預裝工具**：kubectl、eksctl、helm 等
- ✅ **自動權限**：使用當前 IAM 身份
- ✅ **無需配置**：AWS 憑證自動設定
- ✅ **穩定網路**：AWS 內部網路連接

## 🛠️ 本地環境部署

### 前置需求
```bash
# 安裝 AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 配置 AWS 憑證
aws configure
```

### 執行部署
```bash
# 進入 Chapter 2 目錄
cd 2.eks-cluster-setup

# 執行一鍵部署腳本
chmod +x one-click-cmd.sh
./one-click-cmd.sh
```

## 📋 腳本執行內容

### 自動檢測與安裝
1. **檢查現有工具**：kubectl、eksctl、helm
2. **檢查現有集群**：避免重複創建
3. **智能跳過**：已存在的資源不重複創建

### 部署步驟
1. **建立 EKS 集群**：myeks (3 個 t3.medium 節點)
2. **安裝 AWS Load Balancer Controller**
3. **配置 EBS CSI Driver**
4. **安裝核心附加組件**
5. **安裝 Metrics Server**
6. **創建命名空間**：fish-game-system

## 🔍 驗證部署

### 基本檢查
```bash
# 檢查節點
kubectl get nodes

# 檢查系統 Pods
kubectl get pods -n kube-system

# 檢查附加組件
eksctl get addons --cluster myeks
```

### 詳細檢查
```bash
# Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# Metrics Server
kubectl get deployment metrics-server -n kube-system

# EBS CSI Driver
kubectl get pods -n kube-system | grep ebs-csi

# 命名空間
kubectl get namespace fish-game-system
```

### 預期輸出
```bash
# kubectl get nodes
NAME                                               STATUS   ROLES    AGE   VERSION
ip-192-168-xx-xx.ap-northeast-2.compute.internal   Ready    <none>   5m    v1.32.x
ip-192-168-xx-xx.ap-northeast-2.compute.internal   Ready    <none>   5m    v1.32.x
ip-192-168-xx-xx.ap-northeast-2.compute.internal   Ready    <none>   5m    v1.32.x

# eksctl get addons --cluster myeks
NAME               VERSION              STATUS  ISSUES  IAMROLE
aws-ebs-csi-driver v1.x.x-eksbuild.x   ACTIVE  0       AmazonEKS_EBS_CSI_DriverRole
coredns            v1.x.x-eksbuild.x   ACTIVE  0
kube-proxy         v1.x.x-eksbuild.x   ACTIVE  0
vpc-cni            v1.x.x-eksbuild.x   ACTIVE  0
```

## 🛠️ 故障排除

### 常見問題

#### 1. 權限不足
```bash
# 檢查當前身份
aws sts get-caller-identity

# 確保有以下權限:
# - AmazonEKSClusterPolicy
# - AmazonEKSWorkerNodePolicy
# - AmazonEKS_CNI_Policy
# - AmazonEC2ContainerRegistryReadOnly
```

#### 2. 集群創建失敗
```bash
# 檢查 CloudFormation 堆疊
aws cloudformation describe-stacks --stack-name eksctl-myeks-cluster

# 檢查日誌
eksctl utils describe-stacks --region ap-northeast-2 --cluster myeks
```

#### 3. Load Balancer Controller 安裝失敗
```bash
# 檢查 OIDC provider
eksctl utils associate-iam-oidc-provider --region ap-northeast-2 --cluster myeks --approve

# 重新安裝
helm uninstall aws-load-balancer-controller -n kube-system
# 然後重新執行腳本
```

#### 4. 節點無法加入集群
```bash
# 檢查節點群組
eksctl get nodegroup --cluster myeks

# 檢查安全群組
aws ec2 describe-security-groups --filters "Name=group-name,Values=*myeks*"
```

## 🧹 清理資源

### 完整清理 (謹慎使用)
```bash
# 刪除 EKS 集群和所有相關資源
eksctl delete cluster --name myeks --region ap-northeast-2

# 清理 IAM 政策 (可選)
aws iam delete-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy
```

### 部分清理
```bash
# 只刪除應用程式
kubectl delete namespace fish-game-system

# 保留集群，刪除 Load Balancer Controller
helm uninstall aws-load-balancer-controller -n kube-system
```

## 📊 成本估算

### 預估月費用 (ap-northeast-2)
| 資源 | 規格 | 月費用 (USD) |
|------|------|-------------|
| EKS 控制平面 | 1 個集群 | $73 |
| EC2 節點 | 3 x t3.medium | ~$90 |
| EBS 儲存 | 60GB gp3 | ~$6 |
| NAT Gateway | 2 個 AZ | ~$45 |
| 資料傳輸 | 估計 | ~$10 |

**總計**: ~$224 USD/月

### 成本優化建議
- 使用 Spot 實例節省 70% 節點成本
- 調整節點數量 (最小 1 個)
- 使用 Fargate 按需付費

## 📋 檢查清單

### EKS 集群建立完成
- [ ] EKS 集群 `myeks` 成功建立
- [ ] 3 個工作節點正常運行 (`kubectl get nodes`)
- [ ] kubectl 可以連接集群
- [ ] AWS Load Balancer Controller 運行正常
- [ ] EBS CSI Driver 安裝完成
- [ ] Metrics Server 運行正常
- [ ] 命名空間 `fish-game-system` 已創建

### 網路和安全
- [ ] VPC 和子網路自動創建
- [ ] 安全群組規則正確配置
- [ ] OIDC provider 已關聯
- [ ] IAM 角色和政策正確設定

### 監控和日誌
- [ ] CloudWatch 日誌群組已創建
- [ ] Metrics Server 收集資源使用率
- [ ] 可以查看 Pod 和節點指標

## 🔗 相關資源

### AWS 官方文檔
- [Amazon EKS 用戶指南](https://docs.aws.amazon.com/eks/latest/userguide/)
- [eksctl 官方文檔](https://eksctl.io/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

### 故障排除
- [EKS 故障排除指南](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [kubectl 備忘單](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## 📚 下一步

完成本章後，你將擁有：
- ✅ **完整的 EKS 集群** - 準備部署應用程式
- ✅ **Load Balancer 支援** - 可以創建 ALB/NLB
- ✅ **儲存支援** - EBS 持久化儲存
- ✅ **監控基礎** - Metrics Server 和 CloudWatch 日誌
- ✅ **安全配置** - IAM 角色和 RBAC

**準備進入 Chapter 3: 微服務部署到 EKS** 🎮

---

**🚀 你的 Kubernetes 集群已經準備好了！**

## 💡 小貼士

### CloudShell 使用技巧
- 使用 `Ctrl+C` 中斷長時間運行的命令
- 使用 `screen` 或 `tmux` 保持會話
- 定期保存重要文件到 S3

### 除錯技巧
```bash
# 查看詳細日誌
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# 查看事件
kubectl get events --sort-by=.metadata.creationTimestamp

# 查看資源使用
kubectl top nodes
kubectl top pods -n kube-system
```
