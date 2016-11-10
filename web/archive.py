import os
import glob
import datetime
from flask import Flask, jsonify
app = Flask(__name__)
archive_dir = '/var/www/camp/archive'

@app.route("/getPics/<int:date>")
def getPics(date):
   today=datetime.datetime.now().strftime('%y%m%d')
   sorted_files = sorted(glob.glob(archive_dir+'/photo/%s/*.jpg' % date), key=os.path.getmtime)
   sorted_files = [os.path.basename(x) for x in sorted_files]
   return jsonify({'sorted_files':sorted_files})

if __name__ == "__main__":
   app.run(debug=True,host="0.0.0.0",port=5002)
