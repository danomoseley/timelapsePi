import os
import glob
import fnmatch
import datetime
from flask import Flask, jsonify, send_file, abort, send_from_directory
app = Flask(__name__)

today=None
sorted_files = None
sorted_file_indexes = {}

@app.route('/')
def scroll():
   return app.send_static_file('infiniteScroll.html')

@app.route('/js/<path:path>')
def send_js(path):
   return send_from_directory('js', path)

@app.route('/archive/<path:path>')
def send_img(path):
   return send_from_directory('../../archive', path)

@app.route("/getLatestPic")
def getLatestPic():
   today=datetime.datetime.now().strftime('%y%m%d')
   global sorted_files
   global sorted_file_indexes
   sorted_files = sorted(glob.glob('../../archive/photo/%s/*.jpg' % today), key=os.path.getmtime)
   i = 0
   for file in sorted_files:
      sorted_file_indexes[file] = i
      i += 1
   newest = sorted_files[-1]
   filename = os.path.basename(newest)
   return jsonify({'path':newest[2:],'date':int(filename[0:6]),'timestamp':int(filename[0:10])})

@app.route("/getNextPic/<int:timestamp>", defaults={'interval': 1})
@app.route('/getNextPic/<int:timestamp>/<int:interval>')
def getNextPic(timestamp, interval):
   timestamp_filename = '../../archive/photo/%s/%s.jpg' % (str(timestamp)[0:6], str(timestamp))
   if timestamp_filename in sorted_files:
      timestamp_index = sorted_file_indexes[timestamp_filename]
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
   app.run(debug=True,host="0.0.0.0",port=5001)
