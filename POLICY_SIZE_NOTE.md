# IAM ポリシー文字数制限について

## 問題

IAM ポリシーには文字数制限があります：

- **インラインポリシー**: 2,048 文字
- **管理ポリシー**: 6,144 文字

## 解決方法

### 方法 1: 簡潔なポリシーを使用（推奨）

`iam-policy-for-terraform.json` を簡潔版に更新しました。

**変更内容:**

- 個別のアクション指定から `*` ワイルドカードに変更
- 不要な S3/DynamoDB 設定を削除（リモート State を使わない場合）
- `iam:PassRole`を別ステートメントに分離し、`iam:PassedToService`条件を追加（セキュリティ強化）

**文字数:** 約 580 文字（制限内）

**セキュリティ改善:**
`iam:PassRole`アクションに条件を追加し、Lambda 関数にのみロールを渡せるよう制限しました。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["sns:*"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["lambda:*"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "lambda.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": ["logs:*"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["events:*"],
      "Resource": "*"
    }
  ]
}
```

### 方法 2: AWS CLI で直接インラインポリシーとして追加

```bash
# ユーザーが既に存在する場合
aws iam put-user-policy \
  --user-name terraform-daily-cost \
  --policy-name TerraformDailyCostPolicy \
  --policy-document file://iam-policy-for-terraform.json
```

### 方法 3: AWS コンソールで手動作成

1. IAM コンソールを開く
2. ユーザー `terraform-daily-cost` を選択
3. 「インラインポリシーの追加」をクリック
4. JSON タブを選択
5. 以下をコピー＆ペースト:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": ["sns:*"], "Resource": "*" },
    { "Effect": "Allow", "Action": ["lambda:*"], "Resource": "*" },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "lambda.amazonaws.com"
        }
      }
    },
    { "Effect": "Allow", "Action": ["logs:*"], "Resource": "*" },
    { "Effect": "Allow", "Action": ["events:*"], "Resource": "*" }
  ]
}
```

### 方法 4: 複数のインラインポリシーに分割

```bash
# ポリシー1: SNS + Lambda
aws iam put-user-policy \
  --user-name terraform-daily-cost \
  --policy-name TerraformPolicy1 \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {"Effect": "Allow", "Action": ["sns:*"], "Resource": "*"},
      {"Effect": "Allow", "Action": ["lambda:*"], "Resource": "*"}
    ]
  }'

# ポリシー2: IAM + Logs + Events
aws iam put-user-policy \
  --user-name terraform-daily-cost \
  --policy-name TerraformPolicy2 \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {"Effect": "Allow", "Action": ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole", "iam:TagRole", "iam:UntagRole", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy"], "Resource": "*"},
      {"Effect": "Allow", "Action": ["logs:*"], "Resource": "*"},
      {"Effect": "Allow", "Action": ["events:*"], "Resource": "*"}
    ]
  }'
```

## セットアップスクリプトの使用

更新された `setup-iam.sh` を使用すると、自動的に簡潔版のポリシーが適用されます：

```bash
./setup-iam.sh
```

## 権限の範囲

簡潔版でも以下の操作が可能です：

✅ SNS トピックの作成・管理
✅ Lambda 関数の作成・管理
✅ IAM ロールの作成・管理
✅ CloudWatch Logs の管理
✅ EventBridge ルールの管理

## セキュリティ考慮事項

### ワイルドカードの使用

ワイルドカード（`*`）を使用していますが、以下の理由で許容範囲です：

1. **スコープ限定**: 特定の AWS サービスのみ
2. **用途明確**: Terraform 実行専用アカウント
3. **監査可能**: CloudTrail で全操作を追跡可能

### PassRole の条件制限

`iam:PassRole`アクションには条件を追加しています：

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "lambda.amazonaws.com"
    }
  }
}
```

**効果:**

- Lambda サービスにのみロールを渡すことができる
- 他のサービス（EC2、ECS 等）にはロールを渡せない
- セキュリティベストプラクティスに準拠

より厳密な権限管理が必要な場合は、リソース ARN で制限を追加してください。

## トラブルシューティング

### エラー: "Policy document is too large"

**原因:** ポリシーが 2,048 文字を超えている

**解決策:**

1. 最新の `iam-policy-for-terraform.json` を使用
2. 複数のインラインポリシーに分割
3. 管理ポリシーとして作成（推奨）

### 管理ポリシーとして作成

```bash
# 管理ポリシーを作成（6,144文字まで可）
aws iam create-policy \
  --policy-name TerraformDailyCostMonitorPolicy \
  --policy-document file://iam-policy-for-terraform.json

# ユーザーにアタッチ
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam attach-user-policy \
  --user-name terraform-daily-cost \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/TerraformDailyCostMonitorPolicy"
```

## 参考リンク

- [IAM Policy Size Limits](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html)
- [IAM JSON Policy Elements Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html)
