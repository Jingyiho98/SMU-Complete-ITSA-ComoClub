import os
import json
import requests
import boto3


def lambda_handler(event, context):

    # Ping sevenrooms to check if down
    res = requests.get("https://demo.sevenrooms.com/api-ext/2_4/venues")

    if not res.status_code:
        print("SevenRooms is still down.")
        return

    nlb_url = os.environ['NLB_URL']

    print("Processing started.")
    # Iterate through each message and call API
    for message in event['Records']:
        print(message)
        receipt_handle = message["receiptHandle"]
        body = message["body"]
        print(str(body))
        body = json.loads(body)

        url = body["url"]
        reservation_request = body["reservationRequest"]

        # Retry API call
        res = requests.post("http://" + nlb_url + url,
                            json=reservation_request)

        print(res.status_code, res.text)

    print("Processing success.")
    return
