import os
import json
import requests
import boto3


def lambda_handler(event, context):
    CREDENTIALS_ARN = os.environ['SEVENROOMS_CREDENTIALS_ARN']
    TOKEN_ARN = os.environ["SEVENROOMS_TOKEN_ARN"]

    # Retrieve endpoint from DynamoDB
    db = boto3.resource('dynamodb')
    table = db.Table('g2team8-endpoint_db')
    endpoint = table.get_item(Key={'name': 'sevenrooms_auth'})['Item']
    url = endpoint['api_link']

    # Retrieve secret from SSM
    sm = boto3.client(service_name='secretsmanager')
    secret = sm.get_secret_value(
        SecretId=CREDENTIALS_ARN)
    secret = json.loads(secret['SecretString'])

    # Prepare post request to Sevenrooms Auth
    body = {
        "client_id": secret['client_id'],
        "client_secret":  secret['client_secret']
    }

    headers = {
        'content-type': 'application/x-www-form-urlencoded'
    }

    r = requests.post(url, data=body, headers=headers)

    TokenString = r.json()['data']['token']

    # Store retrieved token into SSM
    sm.put_secret_value(
        SecretId=TOKEN_ARN, SecretString=TokenString)
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "message": "OK"})
    }
