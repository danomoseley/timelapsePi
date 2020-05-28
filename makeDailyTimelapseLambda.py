import json
import tempfile
import boto3
import os
from subprocess import getstatusoutput
from datetime import datetime, timedelta
import dateutil.tz

eastern = dateutil.tz.gettz('US/Eastern')
date = datetime.now(tz=eastern).strftime('%y%m%d')

def lambda_handler(event, context):
    s3_resource = boto3.resource('s3')
    bucket = s3_resource.Bucket('camp.danomoseley.com')
    tmp_folder = ''
    for object in bucket.objects.filter(Prefix = 'archive/photo/'+date):
        tmp_folder = '/tmp/' + os.path.dirname(object.key)
        if not os.path.exists(tmp_folder):
            os.makedirs(tmp_folder)
        bucket.download_file(object.key, '/tmp/'+ object.key)

    status, message = getstatusoutput("/opt/bin/ffmpeg -r 12 -pattern_type glob -i '%s/*.jpg' -pix_fmt yuv420p -r 30 -codec:v libx264 -profile:v baseline -level 3 -an /tmp/latest_vid_hd.mp4" % tmp_folder)
    
    expires = datetime.utcnow() + timedelta(hours=1)
    bucket.upload_file('/tmp/latest_vid_hd.mp4', 'latest_vid_hd.mp4', ExtraArgs={'Expires': expires})

    if status == 0:
        return {
            'statusCode': 200,
            'body': message
        }
    else:
        return {
            'statusCode': 500,
            'body': message
            }
