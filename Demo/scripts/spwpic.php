<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Улучшенный просмотр изображений</title>
    <style>
        body {
            margin: 0;
            padding: 0 8px;
            font-family: Arial, sans-serif;
            background-color: #f5f5f5;
        }

        .mpic {
            max-width: auto;
            margin: 3px auto;
        }

        .controls {
            text-align: center;
            margin-bottom: 3px;
        }

        #image-container {
            width: 100%;
            height: calc(100vh - 84px);
            margin: auto;
            overflow: hidden;
/*             border: 2px solid #ddd; */
            border-radius: 8px ;
            position: relative;
            cursor: grab;
            user-select: none;
            background-color: #fff;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            box-sizing: border-box;
        }

        #image-container.zoomed {
            cursor: grabbing;
        }

        #zoomable-image {
            max-width: none;
            max-height: none;
            display: block;
            transition: transform 0.2s ease-out;
            transform-origin: 0 0;
            position: absolute;
            top: 0;
            left: 0;
        }

        .btn {
            padding: 10px 15px;
            margin: 1px 4px;
            background-color: #007bff;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            user-select: none;
        }

        .btn:hover {
            background-color: #0056b3;
            user-select: none;
        }

        .btn:disabled {
            background-color: #ccc;
            cursor: not-allowed;
            user-select: none;
        }

        .zoom-info {
            display: inline-block;
            margin-left: 15px;
            font-weight: bold;
            font-size: 14px;
            color: #333;
        }
    </style>
</head>
<body onauxclick="return false" oncontextmenu="return false">
    <div class="mpic">
        <?php
        function mscale($qmsc) {
            // Экранируем URL для безопасности
            $safeUrl = htmlspecialchars($qmsc, ENT_QUOTES, 'UTF-8');

            echo '
            <div class="controls">
                <button class="btn" onclick="resetView()" title="Сбросить масштаб">↺ Сброс</button>
                <button class="btn" onclick="resetViewnative()" title="Сбросить масштаб до нативного">↺ Нативный</button>
                <button class="btn" onclick="zoomIn()" title="Увеличить">+</button>
                <button class="btn" onclick="zoomOut()" title="Уменьшить">-</button>
                <span class="zoom-info">Масштаб: <span id="zoom-level">100%</span></span>
            </div>

            <div id="image-container">
                <img src="' . $safeUrl . '"
                     id="zoomable-image"
                     alt="Изображение для масштабирования"
                     draggable="false">
            </div>

            <script>
            (function() {

                const container = document.getElementById("image-container");
                const img = document.getElementById("zoomable-image");
                const zoomLevel = document.getElementById("zoom-level");

                let scale = 1;
                const minScale = 0.01;
                const maxScale = 2100000;
                const zoomStep = 0.1;

                let isDragging = false;
                let startX, startY;
                let startTranslateX = 0, startTranslateY = 0;
                let currentTranslateX = 0, currentTranslateY = 0;

                // Центрирование изображения
                function centerImage() {
                    setSVGDimensions();

                    let imgWidth = img.naturalWidth;
                    let imgHeight = img.naturalHeight;

                    if (isSVG(img.src)) {
                        imgWidth = parseInt(img.style.width) || imgWidth;
                        imgHeight = parseInt(img.style.height) || imgHeight;
                    }

                    if (!imgWidth || !imgHeight) return;

                    const containerRect = container.getBoundingClientRect();
                    const imgRatio = imgWidth / imgHeight;
                    const containerRatio = containerRect.width / containerRect.height;

                    if (imgRatio > containerRatio) {
                        scale = (containerRect.width) / imgWidth;
                    } else {
                        scale = (containerRect.height) / imgHeight;
                    }

                    currentTranslateX = (containerRect.width - imgWidth * scale) / 2;
                    currentTranslateY = (containerRect.height - imgHeight * scale) / 2;

                    applyTransform();
                    updateZoomInfo();
                }

                // Ограничение границ
                function limitBounds() {
                    const containerRect = container.getBoundingClientRect();

                    let imgWidth = img.naturalWidth;
                    let imgHeight = img.naturalHeight;

                    if (isSVG(img.src)) {
                        imgWidth = parseInt(img.style.width) || imgWidth;
                        imgHeight = parseInt(img.style.height) || imgHeight;
                    }

                    const scaledWidth = imgWidth * scale;
                    const scaledHeight = imgHeight * scale;

                    const maxX = 0;
                    const maxY = 0;
                    const minX = Math.min(containerRect.width - scaledWidth, 0);
                    const minY = Math.min(containerRect.height - scaledHeight, 0);

                    currentTranslateX = Math.max(minX, Math.min(maxX, currentTranslateX));
                    currentTranslateY = Math.max(minY, Math.min(maxY, currentTranslateY));
                }

                // Применение трансформации
                function applyTransform() {
                    limitBounds();
                    img.style.transform = `translate(${currentTranslateX}px, ${currentTranslateY}px) scale(${scale})`;
                }

                // Обновление информации о масштабе
                function updateZoomInfo() {
                    zoomLevel.textContent = Math.round(scale * 100) + "%";
                }

                // Функция для определения, является ли изображение SVG
                function isSVG(url) {
                    return url.toLowerCase().endsWith(".svg") ||
                        (url.indexOf("data:image/svg+xml") !== -1);
                }

                // Функция установки размеров для SVG
                function setSVGDimensions() {
                    if (isSVG(img.src)) {
                        if (!img.getAttribute("data-svg-width")) {
                            img.setAttribute("data-svg-width", img.width || 800);
                            img.setAttribute("data-svg-height", img.height || 600);
                        }

                        img.style.width = (img.getAttribute("data-svg-width") || 800) + "px";
                        img.style.height = (img.getAttribute("data-svg-height") || 600) + "px";
                    }
                }

                // Функции управления изображения
                window.resetView = function() {
                    if (img.complete) {
                        centerImage();
                    } else {
                        img.onload = centerImage;
                    }
                };

                // Инициализация при загрузке изображения
                resetView();
                // img.style.transition = "transform 0.2s ease-out";

                // Масштабирование колесом мыши
                container.addEventListener("wheel", (e) => {
                    e.preventDefault();
                    const rect = container.getBoundingClientRect();
                    const mouseX = e.clientX - rect.left;
                    const mouseY = e.clientY - rect.top;

                    const delta = e.deltaY || e.wheelDelta;
                    const zoomDirection = delta > 0 ? -1 : 1;

                    const newScale = Math.max(minScale, Math.min(maxScale, scale + zoomDirection * zoomStep * scale));
                    if (newScale == maxScale) { return }
                    const scaleFactor = newScale / (newScale - zoomDirection * zoomStep * scale);
                    scale = newScale

                    currentTranslateX = mouseX - scaleFactor * (mouseX - currentTranslateX);
                    currentTranslateY = mouseY - scaleFactor * (mouseY - currentTranslateY);

                    applyTransform();
                    updateZoomInfo();
                });

                // Начало перетаскивания
                container.addEventListener("mousedown", (e) => {
                    isDragging = true;
                    container.classList.add("zoomed");
                    startX = e.clientX;
                    startY = e.clientY;
                    startTranslateX = currentTranslateX;
                    startTranslateY = currentTranslateY;
                    e.preventDefault();
                });

                // Завершение перетаскивания
                window.addEventListener("mouseup", () => {
                    if (!isDragging) return;
                    isDragging = false;
                    container.classList.remove("zoomed");
                });

                // Процесс перетаскивания
                container.addEventListener("mousemove", (e) => {
                    if (!isDragging) return;

                    const dx = e.clientX - startX;
                    const dy = e.clientY - startY;

                    currentTranslateX = startTranslateX + dx;
                    currentTranslateY = startTranslateY + dy;
                    // img.style.transition = "none";
                    applyTransform();
                    // img.style.transition = "transform 0.2s ease-out";
                });

                // Касание для мобильных устройств
                let touchStartX = null, touchStartY = null;
                let touchStartDistance = 0;

                container.addEventListener("touchstart", (e) => {
                    if (e.touches.length === 1) {
                        touchStartX = e.touches[0].clientX;
                        touchStartY = e.touches[0].clientY;
                        startTranslateX = currentTranslateX;
                        startTranslateY = currentTranslateY;
                    } else if (e.touches.length === 2) {
                        touchStartX = touchStartY = null;
                        const touch1 = e.touches[0];
                        const touch2 = e.touches[1];
                        touchStartDistance = Math.hypot(
                            touch2.clientX - touch1.clientX,
                            touch2.clientY - touch1.clientY
                        );
                    }
                });

                container.addEventListener("touchmove", (e) => {
                    e.preventDefault();
                    if (e.touches.length === 1 && touchStartX != null && touchStartY != null) {
                        const dx = e.touches[0].clientX - touchStartX;
                        const dy = e.touches[0].clientY - touchStartY;

                        currentTranslateX = startTranslateX + dx;
                        currentTranslateY = startTranslateY + dy;

                        applyTransform();
                    } else if (e.touches.length === 2) {
                        const touch1 = e.touches[0];
                        const touch2 = e.touches[1];
                        const currentDistance = Math.hypot(
                            touch2.clientX - touch1.clientX,
                            touch2.clientY - touch1.clientY
                        );

                        if (touchStartDistance > 0) {
                            const rect = container.getBoundingClientRect();
                            const centerX = (touch1.clientX + touch2.clientX) / 2 - rect.left;
                            const centerY = (touch1.clientY + touch2.clientY) / 2 - rect.top;

                            const scaleChange = currentDistance / touchStartDistance;
                            const newScale = Math.max(minScale, Math.min(maxScale, scale * scaleChange));
                            const scaleFactor = newScale / scale;
                            scale = newScale;

                            currentTranslateX = centerX - scaleFactor * (centerX - currentTranslateX);
                            currentTranslateY = centerY - scaleFactor * (centerY - currentTranslateY);

                            applyTransform();
                            updateZoomInfo();
                        }
                        touchStartDistance = currentDistance;
                    }
                });

                // Двойной клик для масштабирования
                container.addEventListener("dblclick", (e) => {
                    const rect = container.getBoundingClientRect();
                    const mouseX = e.clientX - rect.left;
                    const mouseY = e.clientY - rect.top;
                    handleZoom(mouseX, mouseY);
                });

                function handleZoom(x, y) {
                    if (scale < 2) {
                        scale = 2;
                        currentTranslateX = x - (x - currentTranslateX) * 2;
                        currentTranslateY = y - (y - currentTranslateY) * 2;
                    } else {
                        scale = 1;
                        currentTranslateX = 0;
                        currentTranslateY = 0;
                    }
                    applyTransform();
                    updateZoomInfo();
                }

                window.resetViewnative = function() {
                    scale = 1;
                    currentTranslateX = 0;
                    currentTranslateY = 0;
                    applyTransform();
                    updateZoomInfo();
                };

                function UpdateZoom(scaleFactor) {
                    const containerRect = container.getBoundingClientRect();
                    const rect = container.getBoundingClientRect();
                    const centerX = containerRect.left + (containerRect.width / 2) - rect.left;
                    const centerY = containerRect.top + (containerRect.height / 2) - rect.top;

                    currentTranslateX = centerX - scaleFactor * (centerX - currentTranslateX);
                    currentTranslateY = centerY - scaleFactor * (centerY - currentTranslateY);

                    applyTransform();
                    updateZoomInfo();
                }

                window.zoomIn = function() {
                    const newScale = Math.min(maxScale, scale + zoomStep * scale);
                    if (newScale == maxScale) { return }
                    const scaleFactor = newScale / (newScale - zoomStep * scale);
                    scale = newScale
                    UpdateZoom(scaleFactor);
                }

                window.zoomOut = function() {
                    const newScale = Math.max(minScale, scale - zoomStep * scale);
                    const scaleFactor = newScale / (newScale + zoomStep * scale);
                    scale = newScale
                    UpdateZoom(scaleFactor);
                }

                // Обработчики для кнопок + и -
                let zoomInInterval = null;
                let zoomOutInterval = null;

                function zoomInIntervalNull() {
                    if (zoomInInterval) {
                        clearInterval(zoomInInterval);
                        zoomInInterval = null;
                    }
                }
                function zoomOutIntervalNull() {
                    if (zoomOutInterval) {
                        clearInterval(zoomOutInterval);
                        zoomOutInterval = null;
                    }
                }

                document.querySelector(\'button[title="Увеличить"]\').addEventListener(\'mousedown\', () => {
                    if (zoomInInterval) clearInterval(zoomInInterval);
                    zoomInInterval = setInterval(() => { zoomIn(); }, 100);
                });
                document.querySelector(\'button[title="Увеличить"]\').addEventListener(\'mouseup\', () => { zoomInIntervalNull(); });
                document.querySelector(\'button[title="Увеличить"]\').addEventListener(\'mouseleave\', () => { zoomInIntervalNull(); });

                document.querySelector(\'button[title="Уменьшить"]\').addEventListener(\'mousedown\', () => {
                    if (zoomOutInterval) clearInterval(zoomOutInterval);
                    zoomOutInterval = setInterval(() => { zoomOut(); }, 100);
                });
                document.querySelector(\'button[title="Уменьшить"]\').addEventListener(\'mouseup\', () => { zoomOutIntervalNull(); });
                document.querySelector(\'button[title="Уменьшить"]\').addEventListener(\'mouseleave\', () => { zoomOutIntervalNull(); });

                // Обработчики для тачпада/сенсорного экрана
                function handleTouchStart(e) {
                    const buttonTitle = e.target.getAttribute(\'title\');

                    if (buttonTitle === "Увеличить") {
                        if (zoomInInterval) clearInterval(zoomInInterval);
                        zoomInInterval = setInterval(() => { zoomIn(); }, 100);
                    }
                    else if (buttonTitle === "Уменьшить") {
                        if (zoomOutInterval) clearInterval(zoomOutInterval);
                        zoomOutInterval = setInterval(() => { zoomOut(); }, 100);
                    }
                }

                // Применяем обработчики к кнопкам
                document.querySelector(\'button[title="Увеличить"]\').addEventListener(\'touchstart\', handleTouchStart, { passive: false });
                document.querySelector(\'button[title="Увеличить"]\').addEventListener(\'touchend\', zoomInIntervalNull, { passive: false });
                document.querySelector(\'button[title="Увеличить"]\').addEventListener(\'touchcancel\', zoomInIntervalNull, { passive: false });

                document.querySelector(\'button[title="Уменьшить"]\').addEventListener(\'touchstart\', handleTouchStart, { passive: false });
                document.querySelector(\'button[title="Уменьшить"]\').addEventListener(\'touchend\', zoomOutIntervalNull, { passive: false });
                document.querySelector(\'button[title="Уменьшить"]\').addEventListener(\'touchcancel\', zoomOutIntervalNull, { passive: false });
            })();
            </script>';
        }
        ?>

        <?php
        if (($_GET['func'] ?? '') === 'mscale') {
            mscale($_GET['qmsc'] ?? '');
        }
        ?>
    </div>
    <script src="../js/System_limitations.js" defer></script>
</body>
</html>
