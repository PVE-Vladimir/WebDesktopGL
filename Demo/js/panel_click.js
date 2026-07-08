$(document).ready(function(){

	$(".pane-list li").click(function(){
    	window.location=$(this).find("a").attr("href");return false;
	});

}); //close doc ready
