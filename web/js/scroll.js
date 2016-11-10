date=parseInt(moment().format('YYMMDD'));
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
   window.addEventListener('mousewheel', function(e){
      if (e.wheelDelta > 0) {
         loadNextPic();
      } else {
         loadPreviousPic();
      }
   });
   getPics();
});

function getPics() {
   $.getJSON( "/live/getPics/"+date, function(data) {
      sorted_files = data['sorted_files'];
      current_index = sorted_files.length-1;
      loadCurentPic();
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
   imgPath = '/archive/photo/'+date+'/'+sorted_files[i]
   $('<img src="'+ imgPath +'">').load(function() {
      $('#container img').remove();
      $(this).appendTo('#container');
      if (touch && callback !== undefined) {
         setTimeout(callback, 17); // 60fps - 1 hour in timelapse per second 
      }
   });
}

