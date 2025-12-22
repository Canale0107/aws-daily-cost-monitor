#!/bin/bash

# Terraform実行用のIAMリソースを削除するスクリプト
# 使用方法: ./cleanup-iam.sh

set -e

# 色付き出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 設定
POLICY_NAME="TerraformDailyCostMonitorPolicy"
USER_NAME="terraform-daily-cost"

echo -e "${YELLOW}=== Terraform Daily Cost Monitor IAM Cleanup ===${NC}\n"
echo -e "${RED}警告: このスクリプトは以下のリソースを削除します:${NC}"
echo "  - IAMユーザー: $USER_NAME"
echo "  - IAMポリシー: $POLICY_NAME"
echo "  - ユーザーのアクセスキー"
echo ""
echo -e "${YELLOW}本当に削除しますか? (yes/NO): ${NC}"
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "キャンセルしました。"
    exit 0
fi

echo ""

# AWSアカウントIDの取得
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

# 1. ユーザーのアクセスキーを削除
echo "アクセスキーを削除中..."
ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null || echo "")

if [ -n "$ACCESS_KEYS" ]; then
    for key in $ACCESS_KEYS; do
        aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$key"
        echo -e "${GREEN}✓${NC} アクセスキー $key を削除しました"
    done
else
    echo "  アクセスキーは見つかりませんでした"
fi
echo ""

# 2. ポリシーをユーザーからデタッチ
echo "ポリシーをデタッチ中..."
if aws iam get-user --user-name "$USER_NAME" &> /dev/null; then
    aws iam detach-user-policy \
        --user-name "$USER_NAME" \
        --policy-arn "$POLICY_ARN" 2>/dev/null || echo "  ポリシーは既にデタッチされています"
    echo -e "${GREEN}✓${NC} ポリシーをデタッチしました"
else
    echo "  ユーザーが見つかりません"
fi
echo ""

# 3. IAMユーザーを削除
echo "IAMユーザーを削除中..."
if aws iam get-user --user-name "$USER_NAME" &> /dev/null; then
    aws iam delete-user --user-name "$USER_NAME"
    echo -e "${GREEN}✓${NC} ユーザー $USER_NAME を削除しました"
else
    echo "  ユーザーは既に削除されています"
fi
echo ""

# 4. IAMポリシーを削除
echo "IAMポリシーを削除中..."
if aws iam get-policy --policy-arn "$POLICY_ARN" &> /dev/null; then
    aws iam delete-policy --policy-arn "$POLICY_ARN"
    echo -e "${GREEN}✓${NC} ポリシー $POLICY_NAME を削除しました"
else
    echo "  ポリシーは既に削除されています"
fi
echo ""

# 5. AWS CLI プロファイルの削除
echo "AWS CLI プロファイルを削除しますか? (y/N): "
read -r DELETE_PROFILE

if [[ "$DELETE_PROFILE" =~ ^[Yy]$ ]]; then
    aws configure --profile daily-cost-terraform list &> /dev/null && \
        (aws configure set aws_access_key_id "" --profile daily-cost-terraform
         aws configure set aws_secret_access_key "" --profile daily-cost-terraform
         aws configure set region "" --profile daily-cost-terraform
         aws configure set output "" --profile daily-cost-terraform
         echo -e "${GREEN}✓${NC} プロファイル 'daily-cost-terraform' を削除しました") || \
        echo "  プロファイルは見つかりませんでした"
fi
echo ""

echo -e "${GREEN}=== クリーンアップ完了 ===${NC}\n"
echo "注意:"
echo "  - terraform-credentials.txt がある場合は手動で削除してください"
echo "  - Terraformで作成したAWSリソースは別途削除が必要です (terraform destroy)"

