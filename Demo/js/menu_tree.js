
var tree;

function infotree(){
	window.width=300;
	tree = new MooTreeControl({
		div: 'mytree',
		mode: 'files',
		grid: true,
		onClick: function(node) {
                   if(node.data.href == null)
                     node.data.href="othersInfo.htm";
                   if(parent.othersInfo != null)
                    parent.othersInfo.location.href=node.data.href;  
                    else
                      parent.location.href=node.data.href;                      
		}
	},{
		text: 'Справочные сведения',
		open: true
	});

(tree.selected||tree.root).load('othersInfo.xml');
tree.expand();

}
