#!/bin/bash
set -e

echo "🚀 開始 EKS 集群部署..."

# 檢查並設定區域和集群名稱
export AWS_REGION=${AWS_REGION:-ap-northeast-2}
export CLUSTER_NAME=${CLUSTER_NAME:-"myeks-$(date +%s)"}
echo "📍 使用區域: $AWS_REGION"
echo "🏷️  集群名稱: $CLUSTER_NAME"

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
        --with-oidc
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
        --policy-document file://iam_policy.json
else
    echo "✅ Load Balancer Controller IAM 政策已存在"
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

echo ""
echo "🎉 EKS 集群部署完成！"
echo "📋 集群資訊:"
echo "   - 集群名稱: $CLUSTER_NAME"
echo "   - 區域: $AWS_REGION"
echo "   - 節點數量: 3 (t3.medium)"
echo "   - 命名空間: fish-game-system"
echo ""
echo "🚀 準備進入下一章: 微服務部署到 EKS"
