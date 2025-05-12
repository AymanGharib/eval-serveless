from faster_whisper import WhisperModel
import boto3
import os
import json
import time

# Initialize AWS clients
s3 = boto3.client("s3")
sqs = boto3.client("sqs", region_name="us-east-1")
queue_url = os.environ["SQS_QUEUE_URL"]


output_bucket = os.environ.get("OUTPUT_BUCKET", "student-transcripts-bucket")

# Load Whisper model once
model = WhisperModel("tiny", compute_type="int8")

def process_message(message):
    # Parse SQS message body (direct message or SNS wrapped)
    body = json.loads(message["Body"])
    s3_info = json.loads(body.get("Message", "{}")) if "Message" in body else body

    input_bucket = s3_info["bucket"]
    input_key = s3_info["key"]
    student_id = s3_info["student_id"]

    print(f"Processing student_id: {student_id}, file: {input_key}")

    # Download audio
    local_audio = "/tmp/audio.wav"
    s3.download_file(input_bucket, input_key, local_audio)

    # Transcribe
    segments, _info = model.transcribe(local_audio)
    full_transcript = " ".join([segment.text.strip() for segment in segments])

    # Save JSON locally
    local_json = "/tmp/transcript.json"
    with open(local_json, "w") as f:
        json.dump({"transcript": full_transcript}, f)

    # Upload transcript
    output_key = f"{student_id}.json"
    s3.upload_file(local_json, output_bucket, output_key)
    print(f"Transcript uploaded to {output_bucket}/{output_key}")

    # Delete SQS message
    sqs.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=message["ReceiptHandle"]
    )

# Poll loop
while True:
    response = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=1,
        WaitTimeSeconds=10
    )
    messages = response.get("Messages", [])
    for message in messages:
        try:
            process_message(message)
        except Exception as e:
            print("Error processing message:", e)
    time.sleep(1)
