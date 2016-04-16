import os
import glob
import fnmatch
from flask import Flask, jsonify, send_file, abort, send_from_directory
app = Flask(__name__)

@app.route('/')
def scroll():
   return app.send_static_file('infiniteScroll.html')

@app.route('/js/<path:path>')
def send_js(path):
   return send_from_directory('js', path)

@app.route('/archive/<path:path>')
def send_img(path):
   return send_from_directory('../archive', path)

@app.route("/getLatestPic")
def getLatestPic():
   newest = max(glob.iglob('../archive/photo/**/*.jpg'), key=os.path.getctime)
   filename = os.path.basename(newest)
   return jsonify({'path':newest[2:],'date':int(filename[0:6]),'timestamp':int(filename[0:10])})

@app.route("/getNextPic/<int:timestamp>", defaults={'interval': 1})
@app.route('/getNextPic/<int:timestamp>/<int:interval>')
def getNextPic(timestamp, interval):
   sorted_files = sorted(glob.glob('../archive/photo/**/*.jpg'), key=os.path.getmtime)
   timestamp_filename = '../archive/photo/%s/%s.jpg' % (str(timestamp)[0:6], str(timestamp))
   if timestamp_filename in sorted_files:
      timestamp_index = sorted_files.index(timestamp_filename)
      if len(sorted_files) > timestamp_index+interval and timestamp_index > 0:
         previous_pic_path = sorted_files[timestamp_index+interval]
         previous_pic_filename = os.path.basename(previous_pic_path)
         return jsonify({'path':previous_pic_path[2:],'date':int(previous_pic_filename[0:6]),'timestamp':int(previous_pic_filename[0:10])})
   abort(404)

@app.route("/getPreviousPic/<int:timestamp>", defaults={'interval': 1})
@app.route('/getPreviousPic/<int:timestamp>/<int:interval>')
def getPreviousPic(timestamp, interval):
   return getNextPic(timestamp,interval*-1)

if __name__ == "__main__":
   app.run()
