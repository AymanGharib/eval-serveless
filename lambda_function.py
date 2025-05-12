import boto3
import base64
import os
import json
from datetime import datetime

s3 = boto3.client('s3')
transcribe = boto3.client('transcribe')
dynamodb = boto3.client('dynamodb')

BUCKET = os.environ['AUDIO_BUCKET']
TABLE = os.environ['DDB_TABLE']

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        audio_id = body['id']
        original_text = body['original_text']
        audio_data = base64.b64decode(body['audio_base64'])

        # Upload to S3
        audio_key = f"{audio_id}.wav"
        s3.put_object(Bucket=BUCKET, Key=audio_key, Body=audio_data)

        # Store original text in DynamoDB
        dynamodb.put_item(
            TableName=TABLE,
            Item={
                'id': {'S': audio_id},
                'original_text': {'S': original_text},
                'uploaded_at': {'S': datetime.utcnow().isoformat()}
            }
        )

        # Start Transcribe job
        job_uri = f"s3://{BUCKET}/{audio_key}"
        transcribe.start_transcription_job(
            TranscriptionJobName=audio_id,
            LanguageCode='en-US',
            Media={'MediaFileUri': job_uri},
            OutputBucketName="transcribe-output-bucket-12344556"
        )

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Audio uploaded and transcription started."})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
