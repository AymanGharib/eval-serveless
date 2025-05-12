import boto3
import base64
import os
import json
from datetime import datetime

s3 = boto3.client('s3')
dynamodb = boto3.client('dynamodb')
sqs = boto3.client('sqs')

BUCKET = os.environ['AUDIO_BUCKET']
TABLE = os.environ['DDB_TABLE']
SQS_URL = os.environ['SQS_URL']  # Add this to your Lambda environment variables

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        audio_id = body['id']
        original_text = body['original_text']
        audio_data = base64.b64decode(body['audio_base64'])

        # Upload audio to S3
        audio_key = f"{audio_id}.wav"
        s3.put_object(Bucket=BUCKET, Key=audio_key, Body=audio_data)

        # Save original text to DynamoDB
        dynamodb.put_item(
            TableName=TABLE,
            Item={
                'id': {'S': audio_id},
                'original_text': {'S': original_text},
                'uploaded_at': {'S': datetime.utcnow().isoformat()}
            }
        )

        # Prepare and send message to SQS
        message = {
            'student_id': audio_id,
            'bucket': BUCKET,
            'key': audio_key
        }

        sqs.send_message(
            QueueUrl=SQS_URL,
            MessageBody=json.dumps(message)
        )

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Audio uploaded and SQS message sent."})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
