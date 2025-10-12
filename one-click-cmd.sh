#!/bin/bash
set -e
sudo curl -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.32.9/2025-09-19/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
kubectl version --client
curl --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv -v /tmp/eksctl /usr/local/bin
eksctl version
export AWS_REGION=ap-northeast-2
eksctl create cluster --name myeks --version 1.32 --region ${AWS_REGION} --nodegroup-name standard-workers --node-type t3.medium --nodes 3 --nodes-min 1 --nodes-max 4 --managed
kubectl get nodes
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
eksctl utils associate-iam-oidc-provider --region=ap-northeast-2 --cluster=myeks --approve
eksctl create iamserviceaccount --cluster=myeks --namespace=kube-system --name=aws-load-balancer-controller --role-name AmazonEKSLoadBalancerControllerRole --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy --approve
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=myeks --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
eksctl create iamserviceaccount --name ebs-csi-controller-sa --namespace kube-system --cluster myeks --role-name AmazonEKS_EBS_CSI_DriverRole --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --approve
eksctl create addon --name aws-ebs-csi-driver --cluster myeks --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole --force
eksctl create addon --name coredns --cluster myeks --force
eksctl create addon --name kube-proxy --cluster myeks --force
eksctl create addon --name vpc-cni --cluster myeks --force
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
eksctl get addons --cluster myeks
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get deployment metrics-server -n kube-system
kubectl get nodes
kubectl create namespace fish-game-system