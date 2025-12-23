# Terraform 実行のための IAM セットアップガイド

このドキュメントでは、Terraform を実行するために必要な IAM 権限の設定方法を説明します。

## 必要な権限

この Terraform プロジェクトを実行するには、以下の AWS サービスへの権限が必要です：

- **SNS**: トピックとサブスクリプションの作成・管理
- **Lambda**: 関数の作成・管理、権限の設定
- **IAM**: ロールとポリシーの作成・管理
- **CloudWatch Logs**: ロググループの作成・管理
- **EventBridge**: ルールとターゲットの作成・管理

## セットアップ方法

### オプション 1: IAM ユーザーでの実行（推奨：開発環境）

#### 1. IAM ポリシーの作成

AWS マネジメントコンソールで以下の手順を実行：

1. IAM コンソールを開く
2. 左メニューから「ポリシー」を選択
3. 「ポリシーの作成」をクリック
4. 「JSON」タブを選択
5. `iam-policy-for-terraform.json` の内容を貼り付け
6. ポリシー名を設定（例：`TerraformDailyCostMonitorPolicy`）
7. 「ポリシーの作成」をクリック

#### 2. IAM ユーザーの作成とポリシーのアタッチ

1. IAM コンソールで「ユーザー」を選択
2. 「ユーザーを追加」をクリック
3. ユーザー名を入力（例：`terraform-daily-cost`）
4. 「プログラムによるアクセス」を選択
5. 「既存のポリシーを直接アタッチ」を選択
6. 作成したポリシー `TerraformDailyCostMonitorPolicy` を選択
7. ユーザーを作成
8. アクセスキーとシークレットキーを保存

#### 3. AWS CLI の設定

```bash
aws configure --profile daily-cost-terraform
# AWS Access Key ID: (上記で取得したアクセスキー)
# AWS Secret Access Key: (上記で取得したシークレットキー)
# Default region name: ap-northeast-1
# Default output format: json
```

#### 4. プロファイルを使用して Terraform を実行

```bash
export AWS_PROFILE=daily-cost-terraform
cd terraform
terraform init
terraform plan
terraform apply
```

### オプション 2: IAM ロールでの実行（推奨：本番環境・CI/CD）

#### 1. IAM ロールの作成

```bash
# trust-policy.json を作成
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# ロールを作成
aws iam create-role \
  --role-name TerraformDailyCostRole \
  --assume-role-policy-document file://trust-policy.json

# ポリシーをアタッチ
aws iam put-role-policy \
  --role-name TerraformDailyCostRole \
  --policy-name TerraformDailyCostPolicy \
  --policy-document file://iam-policy-for-terraform.json
```

#### 2. ロールを引き受けて実行

```bash
# ロールを引き受ける
aws sts assume-role \
  --role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/TerraformDailyCostRole \
  --role-session-name terraform-session

# 出力された認証情報を環境変数に設定
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

# Terraform ディレクトリに移動
cd terraform

# Terraformを実行
terraform init
terraform plan
terraform apply
```

### オプション 3: 既存の Admin 権限を持つユーザーで実行（簡易）

既に AdministratorAccess ポリシーを持つユーザーがいる場合、そのまま使用できます。

```bash
aws configure --profile admin
export AWS_PROFILE=admin
cd terraform
terraform init
terraform plan
terraform apply
```

**注意**: 本番環境では最小権限の原則に従い、オプション 1 または 2 を推奨します。

## Terraform State 管理（オプション）

リモートステート管理を使用する場合は、以下の設定も必要です。

### S3 バケットと DynamoDB テーブルの作成

```bash
# S3バケットを作成（Terraform State保存用）
aws s3 mb s3://your-terraform-state-bucket --region ap-northeast-1

# バージョニングを有効化
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# DynamoDBテーブルを作成（State Lock用）
aws dynamodb create-table \
  --table-name your-terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1
```

### backend.tf の作成

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "daily-cost/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "your-terraform-lock-table"
    encrypt        = true
  }
}
```

## トラブルシューティング

### 権限エラーが発生した場合

```bash
# 現在の認証情報を確認
aws sts get-caller-identity

# エラーメッセージで不足している権限を確認し、ポリシーに追加
```

### よくあるエラー

#### 1. IAM PassRole エラー

```
Error: Error creating Lambda Function: AccessDeniedException:
User is not authorized to perform: iam:PassRole
```

**解決方法**: IAM ポリシーに `iam:PassRole` 権限が含まれていることを確認

#### 2. Lambda 権限エラー

```
Error: Error adding new Lambda Permission: AccessDeniedException
```

**解決方法**: `lambda:AddPermission` 権限を追加

#### 3. EventBridge 権限エラー

```
Error: Error creating EventBridge rule: AccessDeniedException
```

**解決方法**: `events:PutRule` および `events:PutTargets` 権限を追加

## セキュリティのベストプラクティス

1. **最小権限の原則**: 必要最小限の権限のみを付与
2. **アクセスキーの管理**:
   - アクセスキーは安全に保管
   - 定期的にローテーション
   - `.gitignore` に認証情報ファイルを追加
3. **MFA の使用**: 本番環境では多要素認証を有効化
4. **監査ログ**: CloudTrail で API 呼び出しを記録
5. **タグの活用**: リソースにタグを付けてコスト管理

## IAM ポリシーのカスタマイズ

より厳密な権限管理が必要な場合：

### リソースベースの制限

```json
{
  "Effect": "Allow",
  "Action": "lambda:*",
  "Resource": "arn:aws:lambda:ap-northeast-1:ACCOUNT_ID:function:daily-cost-monitor-*"
}
```

### 条件ベースの制限

```json
{
  "Effect": "Allow",
  "Action": "iam:CreateRole",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:RequestedRegion": "ap-northeast-1"
    }
  }
}
```

## AWS Organizations 環境での実行

Organizations 環境で SCP による制限がある場合は、管理者に以下のサービスへのアクセスを許可してもらってください：

- Amazon SNS
- AWS Lambda
- AWS IAM
- Amazon CloudWatch Logs
- Amazon EventBridge

## 参考リンク

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Terraform AWS Provider Authentication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication)
- [AWS STS AssumeRole](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html)
