$(document).ready(function(){
		$(".zoom").hover(function(){
			$(this).stop().animate({width:"130px",height:"130px",left:"-25px",top:"-25px"}, 400);
			$(this).attr("src","pic2.png");
		},
		function(){
			$(this).stop().animate({width:"50px",height:"50px",left:"0",top:"0"}, 400);
			$(this).attr("src","pic1.png");
		});
});