import os
import glob
import fnmatch
import datetime
from flask import Flask, jsonify, send_file, abort, send_from_directory
app = Flask(__name__)

today=None
sorted_files = None
sorted_file_indexes = {}
archive_path='../archive'

@app.route('/')
def scroll():
   return app.send_static_file('infiniteScroll.html')

@app.route('/js/<path:path>')
def send_js(path):
   return send_from_directory('js', path)

@app.route('/archive/<path:path>')
def send_img(path):
   return send_from_directory(archive_path, path)

@app.route("/getPics/<int:date>")
def getPics(date):
   today=datetime.datetime.now().strftime('%y%m%d')
   sorted_files = sorted(glob.glob('%s/photo/%s/*.jpg' % (archive_path, date)), key=os.path.getmtime)
   sorted_files = [os.path.basename(x) for x in sorted_files]
   return jsonify({'sorted_files':sorted_files})

if __name__ == "__main__":
   app.run(debug=True,host="0.0.0.0",port=5002)
