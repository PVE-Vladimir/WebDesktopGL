let canvas = document.getElementsByClassName('rain')[0];
let c = canvas.getContext('2d');

// Функция для установки размеров canvas
function setCanvasSize() {
	// console.log('Размер окна изменился:');
	//console.log('Ширина:', window.innerWidth, 'px');
	//console.log('Высота:', window.innerHeight, 'px');
    canvas.width = window.innerWidth ;
    canvas.height = window.innerHeight ;
}

// Устанавливаем начальные размеры
setCanvasSize();

function randomNum(max, min) {
	return Math.floor(Math.random() * max) + min;
}

function RainDrops(x, y, endy, velocity, opacity) {

	this.x = x;
	this.y = y;
	this.endy = endy;
	this.velocity = velocity;
	this.opacity = opacity;

	this.draw = function() {
		c.beginPath();
		c.moveTo(this.x, this.y);
		c.lineTo(this.x, this.y - this.endy);
		let lineWidth = 0 ;
		if ( window.innerWidth/window.innerHeight < 1.78 ) {
			lineWidth =  window.innerHeight / 1080 ;
		} else {
			lineWidth =  window.innerWidth / 1920 ;
		}

		c.lineWidth = lineWidth ;
		c.strokeStyle= "rgba(255, 255, 255, " + this.opacity + ")";
		c.stroke();
	}

	this.update = function() {
		let rainEnd = window.innerHeight  + 100;
		if (this.y >= rainEnd) {
			this.y = this.endy - 100;
		} else {
			this.y = this.y + this.velocity;
		}
		this.draw();
	}

}

let rainArray = [];

function initRain() {
    rainArray = [];

	let RainHeight1 = 0;
	let RainHeight2 = 0;
	let RainSpeed1 = 0;
	let RainSpeed2 = 0;
	let RainConstant = window.innerWidth/window.innerHeight;

	if ( RainConstant < 1.78 ) {
		const RainConstant1 = window.innerHeight / 1080 ;
		RainHeight1 = 10 * RainConstant1;
		RainHeight2 = 2 * RainConstant1;
		RainSpeed1 = 20 * RainConstant1;
		RainSpeed2 = 2 * RainConstant1;
	} else {
		const RainConstant2 = window.innerWidth / 1920 ;
		RainConstant = 1;
		RainHeight1 = 10 * RainConstant2;
		RainHeight2 = 2 * RainConstant2;
		RainSpeed1 = 20 * RainConstant2;
		RainSpeed2 = 2 * RainConstant2;
	}

    for (let i = 0; i < 300 * RainConstant ; i++) {
        let rainXLocation = Math.floor(Math.random() * canvas.width);
        let rainYLocation = Math.random() * -500;
        let randomRainHeight = randomNum( RainHeight1, RainHeight2 );
        let randomSpeed = randomNum( RainSpeed1, RainSpeed2 );
        let randomOpacity = Math.random() * 0.55;
        rainArray.push(new RainDrops(rainXLocation, rainYLocation, randomRainHeight, randomSpeed, randomOpacity));
    }
}

initRain();

// Все возможные события
const resizeEvents = [
    'resize',
    'orientationchange',
    'fullscreenchange',
    'webkitfullscreenchange',
    'mozfullscreenchange',
    'MSFullscreenChange'
];

function handleResize() {
	setCanvasSize();
    initRain();
}

// Добавляем один обработчик ко всем событиям
resizeEvents.forEach(event => {
    window.addEventListener(event, handleResize);
});

function animateRain() {

	requestAnimationFrame(animateRain);
	c.clearRect(0,0, window.innerWidth , window.innerHeight );

	for (let i = 0; i < rainArray.length; i++) {
		rainArray[i].update();
	}

}

animateRain();
