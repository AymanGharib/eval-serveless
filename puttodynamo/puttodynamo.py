import boto3
import os
import json
import logging
from jiwer import wer

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3 = boto3.client('s3')
dynamodb = boto3.client('dynamodb')

# Get environment variable
TABLE = os.environ['DDB_TABLE']

def lambda_handler(event, context):
    logger.info("Lambda triggered. Event: %s", json.dumps(event))

    try:
        # 1. Get bucket and object key from S3 event
        record = event['Records'][0]
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        audio_id = key.replace('.json', '')
        logger.info(f"Bucket: {bucket}, Key: {key}, Audio ID: {audio_id}")

        # 2. Download and read the transcription file
        response = s3.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        transcript_json = json.loads(content)

        # 3. Extract transcript text
        transcript_text = transcript_json['results']['transcripts'][0]['transcript']
        logger.info(f"Transcribed text: {transcript_text}")

        # 4. Retrieve original text from DynamoDB
        item = dynamodb.get_item(TableName=TABLE, Key={'id': {'S': audio_id}})
        original_text = item['Item']['original_text']['S']
        logger.info(f"Original text: {original_text}")

        # 5. Compute WER
        wer_score = wer(original_text, transcript_text)
        logger.info(f"WER score: {wer_score}")

        # 6. Analyze timestamps for WPM and pauses
        words = [w for w in transcript_json['results']['items'] if w['type'] == 'pronunciation']
        if len(words) >= 2:
            start_time = float(words[0]['start_time'])
            end_time = float(words[-1]['end_time'])
            duration = end_time - start_time
            word_count = len(words)
            wpm = (word_count / duration) * 60 if duration > 0 else 0

            # Calculate pauses longer than 1s
            pauses = []
            for i in range(1, len(words)):
                prev_end = float(words[i - 1]['end_time'])
                curr_start = float(words[i]['start_time'])
                gap = curr_start - prev_end
                if gap > 1.0:
                    pauses.append(gap)
            num_pauses = len(pauses)
            avg_pause = sum(pauses) / num_pauses if pauses else 0.0
        else:
            wpm = 0
            num_pauses = 0
            avg_pause = 0.0

        logger.info(f"WPM: {wpm}, Pauses: {num_pauses}, Avg Pause: {avg_pause:.2f}s")

        # 7. Update DynamoDB
        response = dynamodb.update_item(
            TableName=TABLE,
            Key={'id': {'S': audio_id}},
            UpdateExpression="SET transcribed_text = :t, wer_score = :w, wpm = :p, pauses = :pa, avg_pause = :ap",
            ExpressionAttributeValues={
                ':t': {'S': transcript_text},
                ':w': {'N': str(round(wer_score, 4))},
                ':p': {'N': str(round(wpm, 2))},
                ':pa': {'N': str(num_pauses)},
                ':ap': {'N': str(round(avg_pause, 2))}
            }
        )
        logger.info(f"DynamoDB update response: {response}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Transcript, WER, and fluency metrics saved to DynamoDB',
                'id': audio_id,
                'wer_score': round(wer_score, 4),
                'wpm': round(wpm, 2),
                'pauses': num_pauses,
                'avg_pause': round(avg_pause, 2)
            })
        }

    except Exception as e:
        logger.error("Error occurred: %s", str(e), exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
