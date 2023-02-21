#!/usr/bin/env python3

import time
from picamera import PiCamera, PiCameraCircularIO
import boto3
from io import BytesIO
import os
from datetime import datetime, timedelta
from PIL import Image
import multiprocessing
from botocore.exceptions import ClientError, EndpointConnectionError
import numpy as np
import picamera.array
import smtplib
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import COMMASPACE, formatdate

video_start_time = None

def sendAlertEmail(errors, attachments=None):
    username = '<YOUR-GMAIL-EMAIL>'
    password = '<YOUR-APP-PASSWORD>'
    
    msg = MIMEMultipart()

    d = datetime.now().strftime("%m/%d/%Y, %H:%M:%S.%f")

    fromaddr = '<YOUR-FROM-EMAIL>'
    msg['From'] = fromaddr 
    toaddrs = ['<YOUR-EMAIL>']
    msg['To'] = COMMASPACE.join(toaddrs)
    msg['Date'] = formatdate(localtime=True)
    msg['Subject'] = f'[ALERT {errors[0]}'
    msg.attach(MIMEText('\n'.join(errors)))

    server = smtplib.SMTP('smtp.gmail.com:587')
    server.starttls()
    server.login(username, password)
    server.sendmail(fromaddr, toaddrs, msg.as_string())
    server.quit()

client = boto3.client('s3')

with PiCamera() as camera:
      camera.resolution = (1640, 1232)
      #camera.resolution = (3280,2464)

      camera.start_preview()
      time.sleep(5)
      date_str = datetime.now().strftime("%y%m%d")
      time_str = datetime.now().strftime("%y%m%d%H%M")

      current_video_filename = f'<YOUR-PATH>{time_str}.h264~incomplete'
      camera.start_recording(current_video_filename, format='h264')

      video_start_time = time.perf_counter()
      current_video_start_time = video_start_time
      client = boto3.client('s3')
      try:
          while True:
              tik = time.perf_counter()
              if tik - current_video_start_time > 60*5:
                  cur_time_str = datetime.now().strftime("%y%m%d%H%M")
                  previous_video_filename = current_video_filename
                  current_video_filename = f'<YOUR-PATH>{cur_time_str}.h264~incomplete'
                  camera.split_recording(current_video_filename, format='h264')
                  os.rename(previous_video_filename, previous_video_filename.replace('~incomplete',''))
                  current_video_start_time = time.perf_counter()

              try:
                  time_str = datetime.now().strftime("%y%m%d%H%M")
                  my_stream = BytesIO()
                  camera.capture(my_stream, 'jpeg', use_video_port=True)
                  my_stream.seek(0)

                  cache_until = datetime.utcnow() + timedelta(minutes=1)
                  client.put_object(
                      Body=my_stream,
                      Bucket='<YOUR-BUCKET-NAME>',
                      Key='latest_pic.jpg',
                      ContentType='image/jpeg',
                      Expires=cache_until
                  )
                  my_stream.seek(0)

                  image = Image.open(my_stream)
                  image.thumbnail((600,450))
                  my_stream = BytesIO()
                  image.save(my_stream, format=image.format)
                  my_stream.seek(0)

                  client.put_object(
                      Body=my_stream,
                      Bucket='<YOUR-BUCKET-NAME>',
                      Key="latest_pic_thumb.jpg",
                      ContentType='image/jpeg',
                      Expires=cache_until
                  )
              except ClientError as e:
                  print(f"Unexpected ClientError: {e}")
              except EndpointConnectionError as e:
                  print("Unexcepted EndpointConnectionError: {e}")

              elapsed = time.perf_counter() - tik
              #print(elapsed)
              camera.wait_recording(60-elapsed)
      finally:
          camera.stop_recording()
          os.rename(current_video_filename, current_video_filename.replace('~incomplete',''))
