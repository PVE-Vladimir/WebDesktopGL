// Функция для проверки клавиш (без изменений)
window.addEventListener('keydown', function(e) {
const key = e.key.toLowerCase();
// Разрешенные комбинации
const allowedCombinations = ['c', 'v', 'a', 'с', 'м', 'ф', 'f5', 'z', 'я']; // кириллические символы
if (key === 'f12' || key === 'f3') {
e.preventDefault();
return false;
}
if (e.ctrlKey) {
if (allowedCombinations.includes(key)) {
return true;
}
e.preventDefault();
return false;
}
}, true);
document.addEventListener('contextmenu', event => event.preventDefault());
window.addEventListener('contextmenu', event => event.preventDefault());
document.addEventListener('click', function(e) {
if (e.ctrlKey && e.button === 0) {
e.preventDefault();
return false;
}
if (e.shiftKey && e.button === 0) {
e.preventDefault();
return false;
}
}, true);
