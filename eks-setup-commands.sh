#!/bin/bash

# 電子捕魚機微服務系統 - EKS 集群建立和 Add-on 安裝腳本

set -e

echo "=== 1. 安裝 kubectl ==="
sudo curl -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.32.9/2025-09-19/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
kubectl version --client

echo "=== 2. 安裝 eksctl ==="
curl --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv -v /tmp/eksctl /usr/local/bin
eksctl version

echo "=== 3. 設定 AWS 區域 ==="
export AWS_REGION=ap-northeast-2
echo "AWS_REGION=${AWS_REGION}"

echo "=== 4. 建立 EKS 集群 ==="
eksctl create cluster \
  --name myeks \
  --version 1.32 \
  --region ${AWS_REGION} \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

echo "=== 5. 等待集群就緒 ==="
kubectl get nodes

echo "=== 6. 安裝必要的 Add-ons ==="

# 6.1 AWS Load Balancer Controller (ALB/NLB 支援)
echo "安裝 AWS Load Balancer Controller..."

# 下載 IAM 政策
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

# 建立 IAM 政策
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# 建立 IAM 服務帳戶
eksctl create iamserviceaccount \
  --cluster=myeks \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# 安裝 AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=myeks \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# 6.2 EBS CSI Driver (持久化存儲支援)
echo "安裝 EBS CSI Driver..."
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster myeks \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster myeks \
  --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole \
  --force

# 6.3 CoreDNS (DNS 解析)
echo "確保 CoreDNS 已安裝..."
eksctl create addon --name coredns --cluster myeks --force

# 6.4 kube-proxy (網路代理)
echo "確保 kube-proxy 已安裝..."
eksctl create addon --name kube-proxy --cluster myeks --force

# 6.5 VPC CNI (網路插件)
echo "確保 VPC CNI 已安裝..."
eksctl create addon --name vpc-cni --cluster myeks --force

# 6.6 Metrics Server (HPA 支援)
echo "安裝 Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "=== 7. 驗證 Add-ons 安裝狀態 ==="
echo "檢查 Add-ons 狀態..."
eksctl get addons --cluster myeks

echo "檢查 AWS Load Balancer Controller..."
kubectl get deployment -n kube-system aws-load-balancer-controller

echo "檢查 Metrics Server..."
kubectl get deployment metrics-server -n kube-system

echo "檢查節點狀態..."
kubectl get nodes

echo "=== 8. 建立命名空間 ==="
kubectl create namespace fish-game-system

echo "=== EKS 集群建立完成！==="
echo "集群名稱: myeks"
echo "區域: ${AWS_REGION}"
echo "節點數量: 3"
echo "命名空間: fish-game-system"
echo ""
echo "下一步："
echo "1. 部署 Redis (ElastiCache 或 Kubernetes)"
echo "2. 部署微服務 (client-service, game-session-service, game-server-service)"
echo "3. 設定 ALB Ingress"
echo "4. 設定域名和 SSL 證書"