import json
import os
from datetime import datetime, timedelta
import boto3
from decimal import Decimal

# Initialize AWS clients
ce_client = boto3.client('ce')
sns_client = boto3.client('sns')
ec2_client = boto3.client('ec2')
rds_client = boto3.client('rds')
s3_client = boto3.client('s3')
lambda_client = boto3.client('lambda')

def get_cost_data(days=7):
    """Get AWS cost data for the specified number of days"""
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=days)
    
    try:
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date.strftime('%Y-%m-%d'),
                'End': end_date.strftime('%Y-%m-%d')
            },
            Granularity='DAILY',
            Metrics=['UnblendedCost'],
            GroupBy=[
                {
                    'Type': 'DIMENSION',
                    'Key': 'SERVICE'
                }
            ]
        )
        return response
    except Exception as e:
        print(f"Error getting cost data: {e}")
        return None

def get_resource_counts():
    """Get counts of various AWS resources"""
    resources = {}
    
    try:
        # EC2 instances
        ec2_response = ec2_client.describe_instances()
        total_instances = 0
        running_instances = 0
        for reservation in ec2_response['Reservations']:
            for instance in reservation['Instances']:
                total_instances += 1
                if instance['State']['Name'] == 'running':
                    running_instances += 1
        resources['EC2'] = {
            'total': total_instances,
            'running': running_instances
        }
    except Exception as e:
        print(f"Error getting EC2 data: {e}")
        resources['EC2'] = {'total': 0, 'running': 0}
    
    try:
        # RDS instances
        rds_response = rds_client.describe_db_instances()
        total_rds = len(rds_response['DBInstances'])
        available_rds = sum(1 for db in rds_response['DBInstances'] 
                           if db['DBInstanceStatus'] == 'available')
        resources['RDS'] = {
            'total': total_rds,
            'available': available_rds
        }
    except Exception as e:
        print(f"Error getting RDS data: {e}")
        resources['RDS'] = {'total': 0, 'available': 0}
    
    try:
        # S3 buckets
        s3_response = s3_client.list_buckets()
        resources['S3'] = {
            'total_buckets': len(s3_response['Buckets'])
        }
    except Exception as e:
        print(f"Error getting S3 data: {e}")
        resources['S3'] = {'total_buckets': 0}
    
    try:
        # Lambda functions
        lambda_response = lambda_client.list_functions()
        resources['Lambda'] = {
            'total_functions': len(lambda_response['Functions'])
        }
    except Exception as e:
        print(f"Error getting Lambda data: {e}")
        resources['Lambda'] = {'total_functions': 0}
    
    return resources

def format_cost_message(cost_data, resources, days):
    """Format cost and resource data into a readable message"""
    if not cost_data:
        return "コストデータの取得に失敗しました。"
    
    message = "=== AWS 日次レポート ===\n\n"
    message += f"📅 期間: 過去{days}日間\n"
    message += f"🕐 生成日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
    
    # Cost summary
    message += "💰 コスト情報\n"
    message += "=" * 50 + "\n\n"
    
    daily_totals = {}
    service_totals = {}
    
    for result in cost_data['ResultsByTime']:
        date = result['TimePeriod']['Start']
        total_cost = Decimal('0')
        
        for group in result['Groups']:
            service = group['Keys'][0]
            cost = Decimal(group['Metrics']['UnblendedCost']['Amount'])
            
            if cost > Decimal('0.01'):  # Only show services with significant cost
                if service not in service_totals:
                    service_totals[service] = Decimal('0')
                service_totals[service] += cost
                total_cost += cost
        
        daily_totals[date] = total_cost
    
    # Daily costs
    message += "📊 日別コスト:\n"
    for date, cost in sorted(daily_totals.items()):
        message += f"  {date}: ${float(cost):.2f}\n"
    
    total_period_cost = sum(daily_totals.values())
    message += f"\n合計 ({days}日間): ${float(total_period_cost):.2f}\n"
    message += f"平均 (1日あたり): ${float(total_period_cost / days):.2f}\n\n"
    
    # Top services by cost
    message += "🏆 サービス別コスト (上位10件):\n"
    sorted_services = sorted(service_totals.items(), 
                            key=lambda x: x[1], reverse=True)[:10]
    for service, cost in sorted_services:
        message += f"  {service}: ${float(cost):.2f}\n"
    
    # Resource information
    message += "\n\n🔧 リソース情報\n"
    message += "=" * 50 + "\n\n"
    
    message += f"📦 EC2 インスタンス:\n"
    message += f"  総数: {resources['EC2']['total']}\n"
    message += f"  稼働中: {resources['EC2']['running']}\n\n"
    
    message += f"🗄️ RDS インスタンス:\n"
    message += f"  総数: {resources['RDS']['total']}\n"
    message += f"  利用可能: {resources['RDS']['available']}\n\n"
    
    message += f"🪣 S3 バケット:\n"
    message += f"  総数: {resources['S3']['total_buckets']}\n\n"
    
    message += f"λ Lambda 関数:\n"
    message += f"  総数: {resources['Lambda']['total_functions']}\n\n"
    
    message += "=" * 50 + "\n"
    message += "このレポートは自動生成されました。\n"
    
    return message

def send_notification(message, topic_arn):
    """Send notification via SNS"""
    try:
        response = sns_client.publish(
            TopicArn=topic_arn,
            Subject=f"AWS Daily Report - {datetime.now().strftime('%Y-%m-%d')}",
            Message=message
        )
        print(f"Notification sent successfully. MessageId: {response['MessageId']}")
        return True
    except Exception as e:
        print(f"Error sending notification: {e}")
        return False

def lambda_handler(event, context):
    """Main Lambda handler"""
    print("Starting AWS daily cost and resource report generation...")
    
    # Get environment variables
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    days_to_check = int(os.environ.get('DAYS_TO_CHECK', '7'))
    
    if not sns_topic_arn:
        print("ERROR: SNS_TOPIC_ARN environment variable not set")
        return {
            'statusCode': 500,
            'body': json.dumps('SNS_TOPIC_ARN not configured')
        }
    
    # Get cost data
    print(f"Fetching cost data for the last {days_to_check} days...")
    cost_data = get_cost_data(days=days_to_check)
    
    # Get resource counts
    print("Fetching resource information...")
    resources = get_resource_counts()
    
    # Format message
    print("Formatting message...")
    message = format_cost_message(cost_data, resources, days_to_check)
    
    # Send notification
    print("Sending notification...")
    success = send_notification(message, sns_topic_arn)
    
    if success:
        return {
            'statusCode': 200,
            'body': json.dumps('Report sent successfully')
        }
    else:
        return {
            'statusCode': 500,
            'body': json.dumps('Failed to send report')
        }

