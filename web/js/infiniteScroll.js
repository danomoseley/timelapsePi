date=parseInt(moment().format('YYMMDD'));
timestamp=parseInt(moment().format('YYMMDDHHmm'));
continuous=false;
sorted_files=[];

function pad(num, size) {
    var s = num+"";
    while (s.length < size) s = "0" + s;
    return s;
}
function timeToI(time) {
   i=(parseInt(time/100)*60)+time%100;
   return i;
}
function iToTime(i) {
   h=parseInt(i/60)
   h=pad(h,2)
   m=i%60
   m=pad(m,2)
   time=h+''+m;
   return time;
}
$(document).ready(function() {
   $("body").on("swipeleft",function(){
      getNextPic();
   });
   $("body").on("swiperight",function(){
      getPreviousPic();
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
   $.getJSON( "/getPics/"+date, function(data) {
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
      loadPic(current_index);
   }
}

function loadPreviousPic() {
   if (current_index > 0) {
      current_index = current_index - 1;
      loadPic(current_index);
   }
}

function loadPic(i) {
   imgPath = '/archive/photo/'+date+'/'+sorted_files[i]
   $('<img src="'+ imgPath +'">').load(function() {
      if (i == current_index) {
         $('#container img').remove();
         $(this).appendTo('#container');
      }
   });
}
