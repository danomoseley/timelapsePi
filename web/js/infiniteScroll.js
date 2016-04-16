date=parseInt(moment().format('YYMMDD'));
timestamp=parseInt(moment().format('YYMMDDHHmm'));
continuous=false;

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
         getNextPic();
      } else {
         getPreviousPic();
      }
   });
   getCurentPic();
});

function getCurentPic() {
   $.getJSON( "/getLatestPic", function( data ) {
      date = data['date'];
      timestamp = data['timestamp'];
      loadPic();
   });
}

function getNextPic() {
   $.getJSON( "/getNextPic/"+timestamp, function( data ) {
      date = data['date'];
      timestamp = data['timestamp'];
      loadPic(getNextPic);
   });
}

function getPreviousPic() {
   $.getJSON( "/getPreviousPic/"+timestamp, function( data ) {
      date = data['date'];
      timestamp = data['timestamp'];
      loadPic(getPreviousPic);
   });
}

function loadPic(fun) {
   imgPath='/archive/photo/'+date+'/'+timestamp+'.jpg'
   $('<img src="'+ imgPath +'">').load(function() {
      $('#container img').remove();
      $(this).appendTo('#container');
      if (continuous && fun) {
         fun();
      }
   });
}