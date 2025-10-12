# Chapter 0: 開發環境設定

## 概述

本章節提供一個完整的 EC2 User Data 腳本，可以在 EC2 實例啟動時自動完成所有開發環境設定，包含 VS Code Server、Docker、AWS CLI、kubectl 等必要工具。

## 🚀 EC2 實例建立步驟指南

### 步驟 1: 啟動 EC2 實例建立流程

1. 登入 AWS 控制台，進入 EC2 服務
2. 點擊「Launch Instance」按鈕

![EC2 控制台](images/1.ec2.PNG)

### 步驟 2: 開始建立實例

點擊「Launch instance」開始建立新的 EC2 實例

![啟動 EC2](images/2.start-ec2.PNG)

### 步驟 3: 設定實例名稱和作業系統

**實例配置建議：**
- **名稱**: `fish-game-workshop` 或你喜歡的名稱
- **作業系統**: Ubuntu 22.04 LTS (推薦)
- **實例類型**: t3.medium (2 vCPU, 4GB RAM)

![名稱和作業系統](images/3.name-os.PNG)

### 步驟 4: 網路設定

**重要網路配置：**
- ✅ **允許來自網際網路的 HTTPS 流量**
- ✅ **允許來自網際網路的 HTTP 流量** 
- ✅ **允許 SSH 流量**
- 🔧 **編輯安全群組** - 需要額外開放端口 8080 (VS Code Server)

![網路設定](images/4.network.PNG)

**安全群組端口設定：**
- 22 (SSH)
- 80 (HTTP) 
- 443 (HTTPS)
- 8080 (VS Code Server)
- 8080-8083 (開發端口範圍)

**IAM Role 設定（重要）：**

為了讓 Workshop 參與者不需要手動配置 AWS credentials，我們需要為 EC2 實例設定 IAM Role：

#### 步驟 A: 建立 IAM Role

1. 在 AWS 控制台進入 **IAM** 服務，點擊左側選單的 **Roles**，然後點擊 **Create role**

![建立 IAM Role](images/1.iam-create-roles.PNG)

2. 選擇 **AWS service** 作為信任實體類型

![選擇 AWS Service](images/2.iam-aws-service.PNG)

3. 選擇 **EC2** 作為使用案例，然後點擊 **Next**

![選擇 EC2 服務](images/3.iam-aws-service.PNG)

4. 搜尋並附加以下權限政策：
   - ✅ `AmazonEC2ContainerRegistryFullAccess` (ECR 操作)
   - ✅ `AmazonEKSClusterPolicy` (EKS 叢集管理)
   - ✅ `AmazonEKSWorkerNodePolicy` (EKS 節點管理)
   - ✅ `AmazonEKS_CNI_Policy` (網路管理)
   - ✅ `AmazonS3ReadOnlyAccess` (S3 讀取)

![選擇權限政策](images/4.check.PNG)

5. 點擊 **Next**，輸入 Role 名稱：`FishGameWorkshopRole`，然後點擊 **Create role**

#### 步驟 B: 將 IAM Role 附加到 EC2 實例

**方法 1: 在建立 EC2 時附加（推薦）**
1. 在 EC2 建立流程的 **Advanced details** 區段
2. 找到 **IAM instance profile** 下拉選單
3. 選擇剛才建立的 `FishGameWorkshopRole`

![在 EC2 建立時附加 IAM Role](images/4.iam-roles-ec2.PNG)

**方法 2: 為現有 EC2 實例附加**
1. 在 EC2 控制台選擇你的實例
2. 點擊 **Actions** → **Security** → **Modify IAM role**

![修改現有 EC2 的 IAM Role](images/4.edit-iam-roles.PNG)

3. 選擇 `FishGameWorkshopRole`
4. 點擊 **Update IAM role**

設定完成後，EC2 實例就會自動擁有 AWS 權限，不需要手動配置 credentials！

### 步驟 5: 儲存空間配置

**建議儲存配置：**
- **大小**: 100GB (足夠容納所有工具和專案)
- **類型**: gp3 (較佳效能)

![儲存設定](images/5.storage.PNG)

### 步驟 6: User Data 腳本設定

這是最關鍵的步驟！在「Advanced details」→「User data」中：

1. 展開「Advanced details」區段
2. 找到「User data」文字框
3. 複製 `ec2-userdata.sh` 的**完整內容**並貼上

![User Data 設定](images/6.user-data.PNG)

**📋 User Data 腳本功能：**
- ✅ 自動安裝 Docker & Docker Compose
- ✅ 自動安裝 AWS CLI v2  
- ✅ 自動安裝 kubectl, eksctl, Helm
- ✅ 自動安裝 VS Code Server (端口 8080)
- ✅ 自動 Clone 專案程式碼: `https://github.com/hoycdanny/fish-machine-workshop`
- ✅ 自動設定完整的開發環境

### 步驟 7: 啟動實例

1. 檢查所有設定無誤
2. 點擊「Launch instance」
3. 等待實例啟動（約 2-3 分鐘）
4. 等待 User Data 腳本執行完成（約 10-15 分鐘）



## 設定完成後的訪問方式

設定完成後（約 10-15 分鐘），你就可以透過瀏覽器訪問 VS Code Server：

- **VS Code Server**: `http://YOUR_EC2_PUBLIC_IP:8080`
- **預設密碼**: `password`
- **專案位置**: `/home/ubuntu/workshop/fish-game-eks-workshop`

![VS Code Server 登入畫面](images/7.login-vs-code.PNG)

成功登入後，你將看到完整的專案結構，包含所有從 GitHub 下載的微服務程式碼，可以立即開始進行開發和部署工作。

## 驗證檢查

設定完成後，請透過以下命令驗證所有工具都正常安裝：

### 🔧 工具版本檢查

**檢查 Docker 版本**
```bash
docker --version
```
> Docker version 28.5.1, build e180ab8

**檢查 Docker Compose 版本**
```bash
docker-compose --version
```
> Docker Compose version v2.40.0

**檢查 AWS CLI 版本**
```bash
aws --version
```
> aws-cli/2.31.13 Python/3.13.7 Linux/6.8.0-1035-aws exe/x86_64.ubuntu.22

**檢查 kubectl 版本**
```bash
kubectl version --client
```
> Client Version: v1.34.1  
> Kustomize Version: v5.7.1

**檢查 eksctl 版本**
```bash
eksctl version
```
> 0.215.0

**檢查 Helm 版本**
```bash
helm version
```
> version.BuildInfo{Version:"v3.19.0", GitCommit:"3d8990f0836691f0229297773f3524598f46bda6", GitTreeState:"clean", GoVersion:"go1.24.7"}

### 🔐 AWS 權限驗證

**檢查 AWS 身份**
```bash
aws sts get-caller-identity
```
> ```json
> {
>     "UserId": "AROA5YW5LRDK7P4DLTGRP:i-0***f49deb08bf***",
>     "Account": "9464*****461",
>     "Arn": "arn:aws:sts::9464*****461:assumed-role/FishGameWorkshopRole/i-0***f49deb08bf***"
> }
> ```

**檢查 AWS 配置**
```bash
aws configure list
```
> ```
>       NAME                    VALUE             TYPE    LOCATION
>       ----                    -----             ----    --------
>    profile                <not set>             None    None
> access_key     ****************D5CM         iam-role    
> secret_key     ****************rgvq         iam-role    
>     region           ap-northeast-2              env    ['AWS_REGION', 'AWS_DEFAULT_REGION']
> ```

**檢查預設區域**
```bash
aws configure get region
```
> ap-northeast-2

### 📁 專案結構驗證

**進入專案目錄**
```bash
cd /home/ubuntu/workshop/fish-game-eks-workshop
```

**檢查專案結構**
```bash
ls -la
```
> ```
> total 12
> drwxrwxr-x 3 ubuntu ubuntu 4096 Oct 12 06:53 .
> drwxr-xr-x 6 ubuntu ubuntu 4096 Oct 12 06:53 ..
> drwxrwxr-x 7 ubuntu ubuntu 4096 Oct 12 06:53 .git
> ```

**檢查專案內容**
```bash
find . -maxdepth 2 -type d
```
> ```
> .
> ./.git
> ```

**專案目錄應該包含：**
- services/ (微服務程式碼)
- infrastructure/ (基礎設施配置)  
- scripts/ (腳本工具)
- docs/ (文檔)
- README.md (專案說明)

## 故障排除

如果遇到問題，可以 SSH 連接到 EC2 檢查：

```bash
# 檢查 User Data 執行日誌
sudo tail -f /var/log/cloud-init-output.log

# 檢查 VS Code Server 狀態
sudo systemctl status code-server@ubuntu

# 檢查 Docker 狀態
sudo systemctl status docker
```

## 下一步

完成本章節後，請繼續到 Chapter 1: 服務驗證和 ECR 推送。