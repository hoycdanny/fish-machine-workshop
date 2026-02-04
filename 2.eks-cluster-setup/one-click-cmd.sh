#!/bin/bash
set -e

echo "🚀 開始 EKS 集群部署..."

# 檢查並設定區域和集群名稱
export AWS_REGION=${AWS_REGION:-ap-northeast-2}
export CLUSTER_NAME=${CLUSTER_NAME:-"fish-game-cluster"}
export PROJECT_TAG="fish-machine-workshop"
export MANAGED_BY_TAG="2.eks-cluster-setup/one-click-cmd.sh"

echo "📍 使用區域: $AWS_REGION"
echo "🏷️  集群名稱: $CLUSTER_NAME"
echo "🏷️  專案標籤: $PROJECT_TAG"
echo "🏷️  管理標籤: $MANAGED_BY_TAG"

# 檢查 AWS 身份
echo "🔐 檢查 AWS 身份..."
aws sts get-caller-identity

# 安裝 kubectl (CloudShell 可能已有，但確保版本正確)
echo "📦 安裝 kubectl..."
if ! command -v kubectl &> /dev/null || [[ $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion') < "v1.30" ]]; then
    sudo curl -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.32.9/2025-09-19/bin/linux/amd64/kubectl
    sudo chmod +x /usr/local/bin/kubectl
fi
kubectl version --client

# 安裝 eksctl (CloudShell 可能已有，但確保版本正確)
echo "📦 安裝 eksctl..."
if ! command -v eksctl &> /dev/null; then
    curl --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv -v /tmp/eksctl /usr/local/bin
fi
eksctl version

# 檢查是否已有集群
echo "🔍 檢查現有集群..."
if aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION &>/dev/null; then
    echo "⚠️  集群 '$CLUSTER_NAME' 已存在，跳過創建步驟"
    # 更新 kubeconfig
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
else
    echo "🏗️  創建 EKS 集群 (預計需要 15-20 分鐘)..."
    eksctl create cluster \
        --name $CLUSTER_NAME \
        --region $AWS_REGION \
        --nodegroup-name standard-workers \
        --node-type t3.medium \
        --nodes 3 \
        --nodes-min 1 \
        --nodes-max 4 \
        --managed \
        --with-oidc \
        --tags "Project=$PROJECT_TAG,Workshop=$PROJECT_TAG,ManagedBy=$MANAGED_BY_TAG"
    
    echo "🏷️  為 EKS 集群添加標籤..."
    CLUSTER_ARN=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query 'cluster.arn' --output text)
    aws eks tag-resource \
        --resource-arn $CLUSTER_ARN \
        --tags "Project=$PROJECT_TAG,Workshop=$PROJECT_TAG,ManagedBy=$MANAGED_BY_TAG"
fi

# 檢查節點
echo "🔍 檢查集群節點..."
kubectl get nodes

# 安裝 AWS Load Balancer Controller
echo "🔧 安裝 AWS Load Balancer Controller..."

# 下載 IAM 政策
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

# 創建 IAM 政策 (如果不存在)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"

if ! aws iam get-policy --policy-arn $POLICY_ARN &>/dev/null; then
    echo "📋 創建 Load Balancer Controller IAM 政策..."
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file://iam_policy.json \
        --tags "Key=Project,Value=$PROJECT_TAG" "Key=Workshop,Value=$PROJECT_TAG" "Key=ManagedBy,Value=$MANAGED_BY_TAG"
else
    echo "✅ Load Balancer Controller IAM 政策已存在"
    # 為現有政策添加標籤
    aws iam tag-policy \
        --policy-arn $POLICY_ARN \
        --tags "Key=Project,Value=$PROJECT_TAG" "Key=Workshop,Value=$PROJECT_TAG" "Key=ManagedBy,Value=$MANAGED_BY_TAG" 2>/dev/null || true
fi

# 關聯 OIDC provider (如果尚未關聯)
echo "🔗 關聯 OIDC provider..."
eksctl utils associate-iam-oidc-provider --region=$AWS_REGION --cluster=$CLUSTER_NAME --approve

# 創建 service account (如果不存在)
if ! kubectl get serviceaccount aws-load-balancer-controller -n kube-system &>/dev/null; then
    echo "👤 創建 Load Balancer Controller Service Account..."
    eksctl create iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --role-name AmazonEKSLoadBalancerControllerRole \
        --attach-policy-arn=$POLICY_ARN \
        --approve
else
    echo "✅ Load Balancer Controller Service Account 已存在"
fi

# 安裝 Helm (CloudShell 可能已有)
echo "📦 安裝 Helm..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# 安裝 AWS Load Balancer Controller
echo "🚀 部署 AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

if ! helm list -n kube-system | grep aws-load-balancer-controller &>/dev/null; then
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller
else
    echo "✅ AWS Load Balancer Controller 已安裝"
fi

# 安裝 EBS CSI Driver
echo "💾 安裝 EBS CSI Driver..."

# 創建 EBS CSI Driver service account (如果不存在)
if ! kubectl get serviceaccount ebs-csi-controller-sa -n kube-system &>/dev/null; then
    eksctl create iamserviceaccount \
        --name ebs-csi-controller-sa \
        --namespace kube-system \
        --cluster $CLUSTER_NAME \
        --role-name AmazonEKS_EBS_CSI_DriverRole \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --approve
else
    echo "✅ EBS CSI Driver Service Account 已存在"
fi

# 安裝 EBS CSI Driver addon
EBS_CSI_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole"
if ! eksctl get addon --name aws-ebs-csi-driver --cluster $CLUSTER_NAME &>/dev/null; then
    eksctl create addon \
        --name aws-ebs-csi-driver \
        --cluster $CLUSTER_NAME \
        --service-account-role-arn $EBS_CSI_ROLE_ARN \
        --force
else
    echo "✅ EBS CSI Driver addon 已安裝"
fi

# 安裝其他核心 addons
echo "🔧 安裝核心 addons..."

addons=("coredns" "kube-proxy" "vpc-cni")
for addon in "${addons[@]}"; do
    if ! eksctl get addon --name $addon --cluster $CLUSTER_NAME &>/dev/null; then
        echo "📦 安裝 $addon..."
        eksctl create addon --name $addon --cluster $CLUSTER_NAME --force
    else
        echo "✅ $addon 已安裝"
    fi
done

# 安裝 Metrics Server
echo "📊 安裝 Metrics Server..."
if ! kubectl get deployment metrics-server -n kube-system &>/dev/null; then
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
else
    echo "✅ Metrics Server 已安裝"
fi

# 安裝 CloudWatch Container Insights
echo "📊 安裝 CloudWatch Container Insights..."
echo "這將啟用 Pod 日誌和指標收集到 CloudWatch"

# 安裝 CloudWatch Observability addon
if ! eksctl get addon --name amazon-cloudwatch-observability --cluster $CLUSTER_NAME &>/dev/null; then
    echo "📦 安裝 CloudWatch Observability addon..."
    eksctl create addon \
        --name amazon-cloudwatch-observability \
        --cluster $CLUSTER_NAME \
        --force
    echo "✅ CloudWatch Observability addon 安裝完成"
else
    echo "✅ CloudWatch Observability addon 已安裝"
fi

# 等待 Pod 啟動
echo "⏳ 等待 CloudWatch Agent 啟動..."
sleep 15

# 配置 IAM 權限（使用 IRSA）
echo "🔐 配置 CloudWatch IAM 權限（IRSA）..."

# 創建 IAM 政策文件
cat > /tmp/cloudwatch-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "ec2:DescribeInstances"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# 創建或獲取 IAM 政策
CLOUDWATCH_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/CloudWatchAgentServerPolicy"

if ! aws iam get-policy --policy-arn $CLOUDWATCH_POLICY_ARN &>/dev/null; then
    echo "📋 創建 CloudWatch IAM 政策..."
    aws iam create-policy \
        --policy-name CloudWatchAgentServerPolicy \
        --policy-document file:///tmp/cloudwatch-policy.json \
        --tags "Key=Project,Value=$PROJECT_TAG" "Key=Workshop,Value=$PROJECT_TAG" "Key=ManagedBy,Value=$MANAGED_BY_TAG"
    echo "✅ CloudWatch IAM 政策創建完成"
else
    echo "✅ CloudWatch IAM 政策已存在"
fi

# 為 fluent-bit 創建 IRSA
echo "👤 為 fluent-bit 創建 IRSA..."
if ! eksctl get iamserviceaccount --cluster $CLUSTER_NAME --namespace amazon-cloudwatch --name fluent-bit &>/dev/null; then
    eksctl create iamserviceaccount \
        --cluster $CLUSTER_NAME \
        --namespace amazon-cloudwatch \
        --name fluent-bit \
        --attach-policy-arn $CLOUDWATCH_POLICY_ARN \
        --approve \
        --override-existing-serviceaccounts
    echo "✅ fluent-bit IRSA 創建完成"
else
    echo "✅ fluent-bit IRSA 已存在"
fi

# 為 cloudwatch-agent 創建 IRSA
echo "👤 為 cloudwatch-agent 創建 IRSA..."
if ! eksctl get iamserviceaccount --cluster $CLUSTER_NAME --namespace amazon-cloudwatch --name cloudwatch-agent &>/dev/null; then
    eksctl create iamserviceaccount \
        --cluster $CLUSTER_NAME \
        --namespace amazon-cloudwatch \
        --name cloudwatch-agent \
        --attach-policy-arn $CLOUDWATCH_POLICY_ARN \
        --approve \
        --override-existing-serviceaccounts
    echo "✅ cloudwatch-agent IRSA 創建完成"
else
    echo "✅ cloudwatch-agent IRSA 已存在"
fi

# 重啟 Pod 以應用新權限
echo "🔄 重啟 CloudWatch Pods 以應用 IAM 權限..."
kubectl delete pods -n amazon-cloudwatch -l k8s-app=fluent-bit 2>/dev/null || true
kubectl delete pods -n amazon-cloudwatch -l name=cloudwatch-agent 2>/dev/null || true

# 等待 Pod 重啟
echo "⏳ 等待 Pods 重啟完成..."
sleep 20
kubectl wait --for=condition=ready pod -l k8s-app=fluent-bit -n amazon-cloudwatch --timeout=120s 2>/dev/null || echo "⚠️  fluent-bit 可能需要更多時間"
kubectl wait --for=condition=ready pod -l name=cloudwatch-agent -n amazon-cloudwatch --timeout=120s 2>/dev/null || echo "⚠️  cloudwatch-agent 可能需要更多時間"

# 清理臨時文件
rm -f /tmp/cloudwatch-policy.json

echo "✅ CloudWatch Container Insights 配置完成"
echo "📊 Pod 日誌將自動發送到 CloudWatch Logs"
echo "📊 日誌群組: /aws/containerinsights/$CLUSTER_NAME/application"
echo "⏳ 注意：日誌可能需要 5 分鐘才會開始出現在 CloudWatch 中"

# 創建命名空間
echo "📁 創建應用命名空間..."
kubectl create namespace fish-game-system --dry-run=client -o yaml | kubectl apply -f -

# 等待所有組件就緒
echo "⏳ 等待所有組件就緒..."
sleep 30

# 最終檢查
echo "🔍 最終狀態檢查..."
echo "--- 集群節點 ---"
kubectl get nodes

echo "--- 系統 Pods ---"
kubectl get pods -n kube-system | grep -E "(aws-load-balancer-controller|metrics-server|ebs-csi)"

echo "--- Addons 狀態 ---"
eksctl get addons --cluster $CLUSTER_NAME

echo "--- Load Balancer Controller ---"
kubectl get deployment -n kube-system aws-load-balancer-controller

echo "--- Metrics Server ---"
kubectl get deployment metrics-server -n kube-system

echo "--- CloudWatch Container Insights ---"
kubectl get pods -n amazon-cloudwatch 2>/dev/null || echo "⚠️  CloudWatch Container Insights 未安裝"

echo ""
echo "🎉 EKS 集群部署完成！"
echo "📋 集群資訊:"
echo "   - 集群名稱: $CLUSTER_NAME"
echo "   - 區域: $AWS_REGION"
echo "   - 節點數量: 3 (t3.medium)"
echo "   - 命名空間: fish-game-system"
echo ""
echo "🏷️  資源標籤:"
echo "   - Project: $PROJECT_TAG"
echo "   - Workshop: $PROJECT_TAG"
echo "   - ManagedBy: $MANAGED_BY_TAG"
echo ""
echo "🔍 驗證標籤:"
echo "   aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query 'cluster.tags'"
echo ""
echo "🚀 準備進入下一章: 微服務部署到 EKS"
