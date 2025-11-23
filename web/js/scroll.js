sorted_files=[];
touch = false;

$(document).ready(function() {
  $("body").on("swipeleft",function(){
    loadPreviousPic();
  });
  $("body").on("swiperight",function(){
    loadNextPic();
  });
  $("body").bind("touchstart", function(){
    touch = true;
  }).bind("touchend", function(){
    touch = false;
  });
  $("#date").change(function(){
  	date = $(this).val();
  	getPics(date);
  });
  $(document).keydown(function(e) {
    switch(e.which) {
      case 37:
        loadPreviousPic();
      break;
      case 39:
        loadNextPic();
      break;
      default: return;
    }
    e.preventDefault();
  });
  window.addEventListener('mousewheel', function(e){
    if (e.wheelDelta > 0) {
      loadNextPic();
    } else {
      loadPreviousPic();
    }
  });

  AWS.config.update({
    accessKeyId: "CREATE_IAM_USER_WITH_NO_PERMISSIONS",
    secretAccessKey: "CREATE_IAM_USER_WITH_NO_PERMISSIONS"
  });
  today_date = parseInt(moment().format('YYMMDD'));
  getPics(today_date);
  getDays();
});

function getDays(ContinuationToken = null) {
  var s3 = new AWS.S3();
  var params = {
    Bucket: "camp.danomoseley.com",
    Prefix: "archive/photo/",
    Delimiter: "/"
  };

  if (ContinuationToken !== null) {
    params['ContinuationToken'] = ContinuationToken
  } else {
    $('#date').find('option').remove();
  }

  s3.listObjectsV2(params, function(err, data) {
   if (err) {
      console.log(err, err.stack);
    } else {
      for (const i in data.CommonPrefixes) {
        date = data.CommonPrefixes[i].Prefix.split("/")[2];
        date_year = date.substring(0,2);
        date_month = date.substring(2,4);
        date_day = date.substring(4);
        $('#date').append('<option value="'+date+'">'+date_month+'/'+date_day+'/'+date_year+'</option>');
      }
      if (data.IsTruncated) {
        getDays(data.NextContinuationToken)
      } else {
        $('#date').val(date).selectmenu("refresh", true);
      }
    }
  });
}

function getPics(date) {
  var s3 = new AWS.S3();
  var params = {
    Bucket: "camp.danomoseley.com",
    Prefix: "archive/photo/"+date+"/"
  };
  s3.listObjectsV2(params, function(err, data) {
    if (err) {
      console.log(err, err.stack);
    } else {
      sorted_files=data.Contents
      today_date = moment().format('YYMMDD')
      if (date == today_date) {
        current_index = sorted_files.length-1;
      } else {
        current_index = parseInt(sorted_files.length/2)
      }
      
		  loadCurentPic();
    }
  });
}

function loadCurentPic() {
  loadPic(current_index);
}

function loadNextPic() {
  if (current_index < sorted_files.length-1) {
    current_index = current_index + 1;
    loadPic(current_index, loadNextPic);
  }
}

function loadPreviousPic() {
  if (current_index > 0) {
    current_index = current_index - 1;
    loadPic(current_index, loadPreviousPic);
  }
}

function loadPic(i, callback) {
  imgPath = sorted_files[i].Key
  $('<img style="max-height:100%;" src="/'+ imgPath +'">').load(function() {
    $('#container img').remove();
    $(this).appendTo('#container');
    if (touch && callback !== undefined) {
      setTimeout(callback, 17); // 60fps - 1 hour in timelapse per second 
    }
   });
}
