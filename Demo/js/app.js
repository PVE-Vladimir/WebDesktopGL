	let physical = 0 ;
	let physical1 = 0 ;
	let physical2 = 0 ;

function updateTransformMove(clientX, clientY) {

		const innerWidth = ( clientX - window.innerWidth / 2 )  * physical;
		const innerHeight = ( clientY - window.innerHeight / 2 ) * physical;

	Object.assign(document.documentElement, {
		style: `
		--move-x: ${ innerWidth * -.005 * physical2 / physical1 }deg;
		--move-y: ${ innerHeight * .01  * physical2 / physical1 }deg;
		//--move-x: ${(clientX - window.innerWidth / 2) * -.005 * window.devicePixelRatio * physical2 }deg;
		//--move-y: ${(clientY - window.innerHeight / 2) * .01  * window.devicePixelRatio * physical2 }deg;
		`
	})
}

function updateTransformXY () {
		if ( window.innerWidth/window.innerHeight < 1.78 ) {
			const Constant = window.innerHeight * window.devicePixelRatio / 1080;
			physical = 1 / (Constant / window.devicePixelRatio);

			if ( physical > 1.1) {
				physical = 1.1;
			}
			physical1 = Constant;
		} else {
			const Constant = window.innerWidth * window.devicePixelRatio / 1920;
			physical = 1 / (Constant / window.devicePixelRatio);

			if ( physical > 1.1 ) {
				physical = 1.1;
			}
			physical1 = Constant;
		}

        physical2 = window.devicePixelRatio/1.04 + 0.09;

		if (physical2 > 1.25) {
			physical2 = physical2 * 0.4 + 1 ;
		}
}

document.addEventListener('mousemove', (e) => {
		updateTransformXY ();
		updateTransformMove( e.clientX, e.clientY);
})

document.addEventListener("touchmove", (e) => {
		updateTransformXY ();
		updateTransformMove(e.touches[0].clientX, e.touches[0].clientY);
		e.preventDefault();
});



