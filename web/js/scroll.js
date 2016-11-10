date=parseInt(moment().format('YYMMDD'));
sorted_files=[];

$(document).ready(function() {
   $("body").on("swipeleft",function(){
      loadNextPic();
   });
   $("body").on("swiperight",function(){
      loadPreviousPic();
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
      $('#container img').remove();
      $(this).appendTo('#container');
   });
}
