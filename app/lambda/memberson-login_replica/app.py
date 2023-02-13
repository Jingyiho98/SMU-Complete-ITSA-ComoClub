import os
import json
import requests
import boto3


CREDENTIALS_ARN = os.environ['MEMBERSON_CREDENTIALS_ARN']
TOKEN_ARN = os.environ["MEMBERSON_TOKEN_ARN"]


def lambda_handler(event, context):
    print("Login request received.")
    # Handle changed request body from API Gateway
    body = json.loads(event["body"])

    # Check if correct fields provided
    if ("email" not in body) or ("password" not in body):
        return {"statusCode": 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                "body": "Invalid inputs given."}

    EmailAddress = body["email"]
    Password = body["password"]

    # Retrieve memberson login url
    db = boto3.resource('dynamodb')
    table = db.Table('g2team8-endpoint_db')
    endpoint = table.get_item(Key={'name': 'memberson'})['Item']
    profileUrl = endpoint['api_link'] + '/profile'
    print("URL endpoint retrieved.")

    # Retrieve SSM secrets
    sm = boto3.client(service_name='secretsmanager')

    secret = sm.get_secret_value(
        SecretId=CREDENTIALS_ARN)
    secret = json.loads(secret['SecretString'])
    SvcAuth = secret['SvcAuth']

    secret = sm.get_secret_value(
        SecretId=TOKEN_ARN)
    Token = secret["SecretString"]
    print("Secrets retrieved.")

    # Search for email address, reject if unregistered email address on Memberson
    print("Searching for email address.")
    headers = {
        'Content-Type': 'application/json',
        'SvcAuth': SvcAuth,
        'Token': Token
    }

    url = profileUrl + '/search-simple'
    body = {
        "EmailAddress": EmailAddress
    }
    r = requests.post(url, data=json.dumps(body), headers=headers)
    try:
        r = r.json()[0]['CustomerNumber']
    except:
        return {'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': "Email not found"}

    # Login to Memberson
    print("Logging into Memberson")
    url = profileUrl + '/' + r + '/signin'
    body = {
        "Password": Password
    }

    r = requests.post(url, data=json.dumps(body), headers=headers)
    try:
        r = r.json()['Token']
    except:
        raise {'statusCode': 400,
               'body': "Wrong password"}

    # Sync valid Memberson user with Cognito
    print("Syncing Memberson user with Cognito")

    print("Login successful.")
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({'profile_token': r})

    }
