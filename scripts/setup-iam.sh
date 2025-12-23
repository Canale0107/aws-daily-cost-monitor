#!/bin/bash

# Terraform実行用のIAMユーザーとポリシーを作成するスクリプト
# 使用方法: ./setup-iam.sh

set -e

# 色付き出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 設定
POLICY_NAME="TerraformDailyCostMonitorPolicy"
USER_NAME="terraform-daily-cost"
POLICY_FILE="iam-policy-for-terraform.json"

echo -e "${GREEN}=== Terraform Daily Cost Monitor IAM Setup ===${NC}\n"

# AWSアカウントIDの取得
echo "AWSアカウントIDを取得中..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "Account ID: ${GREEN}${ACCOUNT_ID}${NC}\n"

# ポリシーファイルの存在確認
if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}エラー: ${POLICY_FILE} が見つかりません${NC}"
    exit 1
fi

# 1. IAMポリシーの作成
echo "IAMポリシーを作成中..."
POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file://"$POLICY_FILE" \
    --description "Policy for Terraform to manage Daily Cost Monitor resources" \
    --query 'Policy.Arn' \
    --output text 2>/dev/null || \
    aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
    echo -e "${RED}ポリシーの作成に失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} ポリシーが作成されました"
echo -e "  ARN: ${POLICY_ARN}\n"

# 2. IAMユーザーの作成
echo "IAMユーザーを作成中..."
if aws iam get-user --user-name "$USER_NAME" &> /dev/null; then
    echo -e "${YELLOW}! ユーザー ${USER_NAME} は既に存在します${NC}\n"
else
    aws iam create-user --user-name "$USER_NAME"
    echo -e "${GREEN}✓${NC} ユーザーが作成されました\n"
fi

# 3. ポリシーをユーザーにアタッチ
echo "ポリシーをユーザーにアタッチ中..."
if aws iam attach-user-policy --user-name "$USER_NAME" --policy-arn "$POLICY_ARN" 2>&1 | grep -q "LimitExceeded"; then
    echo -e "${YELLOW}! 管理ポリシーの上限に達しています。インラインポリシーとして追加します...${NC}"
    
    # インラインポリシーとして追加
    aws iam put-user-policy \
        --user-name "$USER_NAME" \
        --policy-name "$POLICY_NAME" \
        --policy-document file://"$POLICY_FILE"
    echo -e "${GREEN}✓${NC} インラインポリシーが追加されました\n"
else
    echo -e "${GREEN}✓${NC} ポリシーがアタッチされました\n"
fi

# 4. アクセスキーの作成
echo "アクセスキーを作成しますか? (y/N): "
read -r CREATE_KEY

if [[ "$CREATE_KEY" =~ ^[Yy]$ ]]; then
    echo "アクセスキーを作成中..."
    KEY_OUTPUT=$(aws iam create-access-key --user-name "$USER_NAME" --output json)
    
    ACCESS_KEY=$(echo "$KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
    SECRET_KEY=$(echo "$KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')
    
    echo -e "${GREEN}✓${NC} アクセスキーが作成されました\n"
    echo -e "${YELLOW}=== 重要: 以下の認証情報を安全に保管してください ===${NC}"
    echo -e "AWS Access Key ID: ${GREEN}${ACCESS_KEY}${NC}"
    echo -e "AWS Secret Access Key: ${GREEN}${SECRET_KEY}${NC}\n"
    
    # credentials ファイルに追加
    echo "AWS CLI プロファイルに追加しますか? (y/N): "
    read -r ADD_PROFILE
    
    if [[ "$ADD_PROFILE" =~ ^[Yy]$ ]]; then
        aws configure set aws_access_key_id "$ACCESS_KEY" --profile daily-cost-terraform
        aws configure set aws_secret_access_key "$SECRET_KEY" --profile daily-cost-terraform
        aws configure set region ap-northeast-1 --profile daily-cost-terraform
        aws configure set output json --profile daily-cost-terraform
        
        echo -e "${GREEN}✓${NC} プロファイル 'daily-cost-terraform' が追加されました\n"
        echo "使用方法:"
        echo "  export AWS_PROFILE=daily-cost-terraform"
        echo "  terraform init"
    fi
    
    # 認証情報をファイルに保存
    echo "認証情報をファイルに保存しますか? (y/N): "
    read -r SAVE_FILE
    
    if [[ "$SAVE_FILE" =~ ^[Yy]$ ]]; then
        CREDS_FILE="terraform-credentials.txt"
        cat > "$CREDS_FILE" <<EOF
# Terraform Daily Cost Monitor - AWS Credentials
# 作成日時: $(date)
# ⚠️ このファイルは機密情報を含みます。安全に保管してください。

AWS_ACCESS_KEY_ID=${ACCESS_KEY}
AWS_SECRET_ACCESS_KEY=${SECRET_KEY}
AWS_DEFAULT_REGION=ap-northeast-1

# 使用方法:
# export AWS_ACCESS_KEY_ID=${ACCESS_KEY}
# export AWS_SECRET_ACCESS_KEY=${SECRET_KEY}
# export AWS_DEFAULT_REGION=ap-northeast-1

# または
# export AWS_PROFILE=daily-cost-terraform
EOF
        echo -e "${GREEN}✓${NC} 認証情報が ${CREDS_FILE} に保存されました"
        echo -e "${RED}⚠️  このファイルは .gitignore に含まれていることを確認してください${NC}\n"
    fi
fi

echo -e "${GREEN}=== セットアップ完了 ===${NC}\n"
echo "次のステップ:"
echo "  1. terraform.tfvars.example を terraform.tfvars にコピー"
echo "  2. terraform.tfvars を編集して必要な値を設定"
echo "  3. 以下のコマンドを実行:"
echo ""
echo "     export AWS_PROFILE=daily-cost-terraform"
echo "     terraform init"
echo "     terraform plan"
echo "     terraform apply"
echo ""
echo "詳細は TERRAFORM_SETUP.md を参照してください。"

