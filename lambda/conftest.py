"""
Pytest configuration and fixtures for testing cost_notifier Lambda function.
"""
import pytest
from unittest.mock import Mock, MagicMock
from decimal import Decimal
from datetime import datetime


@pytest.fixture
def mock_cost_response():
    """Mock response from AWS Cost Explorer API"""
    return {
        'ResultsByTime': [
            {
                'TimePeriod': {
                    'Start': '2024-01-01',
                    'End': '2024-01-02'
                },
                'Groups': [
                    {
                        'Keys': ['AmazonEC2'],
                        'Metrics': {
                            'UnblendedCost': {
                                'Amount': '10.50',
                                'Unit': 'USD'
                            }
                        }
                    },
                    {
                        'Keys': ['AmazonRDS'],
                        'Metrics': {
                            'UnblendedCost': {
                                'Amount': '5.25',
                                'Unit': 'USD'
                            }
                        }
                    },
                    {
                        'Keys': ['AmazonS3'],
                        'Metrics': {
                            'UnblendedCost': {
                                'Amount': '0.50',
                                'Unit': 'USD'
                            }
                        }
                    }
                ]
            },
            {
                'TimePeriod': {
                    'Start': '2024-01-02',
                    'End': '2024-01-03'
                },
                'Groups': [
                    {
                        'Keys': ['AmazonEC2'],
                        'Metrics': {
                            'UnblendedCost': {
                                'Amount': '11.00',
                                'Unit': 'USD'
                            }
                        }
                    }
                ]
            }
        ]
    }


@pytest.fixture
def mock_empty_cost_response():
    """Mock empty response from Cost Explorer"""
    return {
        'ResultsByTime': []
    }


@pytest.fixture
def mock_resource_data():
    """Mock resource counts for all services"""
    return {
        'EC2': {
            'total': 3,
            'running': 2
        },
        'RDS': {
            'total': 1,
            'available': 1
        },
        'S3': {
            'total_buckets': 5
        },
        'Lambda': {
            'total_functions': 2
        }
    }


@pytest.fixture
def mock_ce_client(mock_cost_response):
    """Mock Cost Explorer client"""
    client = Mock()
    client.get_cost_and_usage.return_value = mock_cost_response
    return client


@pytest.fixture
def mock_ce_client_exception():
    """Mock Cost Explorer client that raises exception"""
    client = Mock()
    client.get_cost_and_usage.side_effect = Exception("API Error")
    return client


@pytest.fixture
def mock_sns_client():
    """Mock SNS client"""
    client = Mock()
    client.publish.return_value = {
        'MessageId': 'test-message-id-12345'
    }
    return client


@pytest.fixture
def mock_sns_client_exception():
    """Mock SNS client that raises exception"""
    client = Mock()
    client.publish.side_effect = Exception("SNS Error")
    return client


@pytest.fixture
def mock_ec2_client():
    """Mock EC2 client"""
    client = Mock()
    client.describe_instances.return_value = {
        'Reservations': [
            {
                'Instances': [
                    {'State': {'Name': 'running'}},
                    {'State': {'Name': 'running'}}
                ]
            },
            {
                'Instances': [
                    {'State': {'Name': 'stopped'}}
                ]
            }
        ]
    }
    return client


@pytest.fixture
def mock_ec2_client_exception():
    """Mock EC2 client that raises exception"""
    client = Mock()
    client.describe_instances.side_effect = Exception("EC2 Error")
    return client


@pytest.fixture
def mock_rds_client():
    """Mock RDS client"""
    client = Mock()
    client.describe_db_instances.return_value = {
        'DBInstances': [
            {'DBInstanceStatus': 'available'}
        ]
    }
    return client


@pytest.fixture
def mock_rds_client_exception():
    """Mock RDS client that raises exception"""
    client = Mock()
    client.describe_db_instances.side_effect = Exception("RDS Error")
    return client


@pytest.fixture
def mock_s3_client():
    """Mock S3 client"""
    client = Mock()
    client.list_buckets.return_value = {
        'Buckets': [
            {'Name': 'bucket1'},
            {'Name': 'bucket2'},
            {'Name': 'bucket3'},
            {'Name': 'bucket4'},
            {'Name': 'bucket5'}
        ]
    }
    return client


@pytest.fixture
def mock_s3_client_exception():
    """Mock S3 client that raises exception"""
    client = Mock()
    client.list_buckets.side_effect = Exception("S3 Error")
    return client


@pytest.fixture
def mock_lambda_client():
    """Mock Lambda client"""
    client = Mock()
    client.list_functions.return_value = {
        'Functions': [
            {'FunctionName': 'function1'},
            {'FunctionName': 'function2'}
        ]
    }
    return client


@pytest.fixture
def mock_lambda_client_exception():
    """Mock Lambda client that raises exception"""
    client = Mock()
    client.list_functions.side_effect = Exception("Lambda Error")
    return client


@pytest.fixture
def mock_environment(monkeypatch):
    """Mock environment variables"""
    monkeypatch.setenv('SNS_TOPIC_ARN', 'arn:aws:sns:us-east-1:123456789012:test-topic')
    monkeypatch.setenv('DAYS_TO_CHECK', '7')
