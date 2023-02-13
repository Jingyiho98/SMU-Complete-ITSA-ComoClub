import os
import json
import requests
import boto3


def lambda_handler(event, context):
    CREDENTIALS_ARN = os.environ['MEMBERSON_CREDENTIALS_ARN']
    TOKEN_ARN = os.environ["MEMBERSON_TOKEN_ARN"]

    # Retrieve endpoint from DynamoDB
    db = boto3.resource('dynamodb')
    table = db.Table('g2team8-endpoint_db')
    endpoint = table.get_item(Key={'name': 'memberson_auth'})['Item']
    url = endpoint['api_link']

    # Retrieve secret from SSM
    sm = boto3.client(service_name='secretsmanager')
    secret = sm.get_secret_value(
        SecretId=CREDENTIALS_ARN)
    secret = json.loads(secret['SecretString'])

    # Prepare post request to Memberson Auth
    body = {
        "UserName": secret['Username'],
        "Password": secret['Password']
    }

    headers = {
        'Content-Type': 'application/json',
        'SvcAuth': secret['SvcAuth']
    }

    r = requests.post(url, data=json.dumps(body), headers=headers)
    TokenString = r.text.strip('"')

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
