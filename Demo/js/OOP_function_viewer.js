    const divider = document.getElementById('divider');
    const leftPane = document.getElementById('leftPane');
    const overlay = document.getElementById('overlay');

    let isDragging = false;

    divider.addEventListener('mousedown', (e) => {
      e.preventDefault();
      isDragging = true;
      document.body.classList.add('dragging');
      overlay.style.display = 'block'; // показываем перекрывающий слой
    });

    function stopDragging() {
      if (isDragging) {
        isDragging = false;
        document.body.classList.remove('dragging');
        overlay.style.display = 'none'; // скрываем перекрывающий слой
      }
    }

    document.addEventListener('mouseup', stopDragging);
    window.addEventListener('blur', stopDragging);

    function onMouseMove(e) {
      if (!isDragging) return;

      const windowWidth = window.innerWidth;
      let pointerX = e.clientX;

      const minWidth = windowWidth * 0.1;
      const maxWidth = windowWidth * 0.8;

      if (pointerX < minWidth) pointerX = minWidth;
      if (pointerX > maxWidth) pointerX = maxWidth;

      leftPane.style.width = pointerX + 'px';
    }

    // Слушаем mousemove на overlay, чтобы ловить движения мыши даже над iframe
    overlay.addEventListener('mousemove', onMouseMove);
    // Также слушаем на document, если мышь не над overlay (например, быстро ушла)
    document.addEventListener('mousemove', onMouseMove);

    function clearSearchBatton() {
      clearSearchInDocument(document);

      const content = document.getElementById('content');
      const iframes = content.querySelectorAll('iframe');

      iframes.forEach(iframe => {
        try {
          const doc = iframe.contentDocument || iframe.contentWindow.document;
          if (doc) clearSearchInDocument(doc);
        } catch (e) {
          console.warn('Нет доступа к содержимому iframe для очистки:', e);
        }
      });

      document.getElementById('searchInput').value = '';
    }

    function clearSearchInDocument(doc) {
      const marks = doc.querySelectorAll('mark');
      marks.forEach(mark => {
        const parent = mark.parentNode;
        parent.replaceChild(doc.createTextNode(mark.textContent), mark);
        parent.normalize();
      });
    }

    // Очистка выделений и в основном документе, и во всех iframe
    function clearSearch() {
      clearSearchInDocument(document);

      const content = document.getElementById('content');
      const iframes = content.querySelectorAll('iframe');

      iframes.forEach(iframe => {
        try {
          const doc = iframe.contentDocument || iframe.contentWindow.document;
          if (doc) clearSearchInDocument(doc);
        } catch (e) {
          console.warn('Нет доступа к содержимому iframe для очистки:', e);
        }
      });
    }

    // Функция поиска и выделения текста внутри документа (doc)
    function searchInDocument(doc, query) {
      // Экранирование всех специальных символов регулярного выражения
      function escapeRegExp(string) {
        return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      }

      // Создание паттерна, где точка — обычный символ, пробелы вариативны
      function createFlexiblePattern(searchTerm) {
        // Сначала экранируем весь текст, чтобы он интерпретировался буквально
        let escaped = escapeRegExp(searchTerm);

        // Заменяем пробелы на вариативные пробельные символы
        escaped = escaped.replace(/\s+/g, '[\\s\\n\\r]*');

        return escaped;
      }

      // Сбор текстовых узлов
      function collectTextNodes(node, textNodes = []) {
        if (node.nodeType === 3) {
          textNodes.push(node);
        } else if (
          node.nodeType === 1 &&
          !['SCRIPT', 'STYLE', 'MARK'].includes(node.tagName)
        ) {
          for (let child of node.childNodes) {
            collectTextNodes(child, textNodes);
          }
        }
        return textNodes;
      }

      // Подсветка текста
      function highlightText() {
        const textNodes = collectTextNodes(doc.body);
        const fullText = textNodes.map(n => n.nodeValue).join('');

        const pattern = createFlexiblePattern(query);
        const regex = new RegExp(`(${pattern})`, 'gi');

        let offset = 0;
        let endInNodeold = 0;
        let namber = 0;
        let namberold = 0;

        textNodes.forEach(node => {
          const nodeValue = node.nodeValue;
          let match;
          namber++;
          while ((match = regex.exec(fullText)) !== null) {
            const matchStart = match.index;
            const matchEnd = match.index + match[0].length;

            // Проверяем, попадает ли совпадение в текущий узел
            if (matchStart < offset + nodeValue.length && matchEnd > offset) {
              const startInNode = Math.max(0, matchStart - offset);
              const endInNode = Math.min(nodeValue.length, matchEnd - offset);
              let startendInNode = 0;
              if (startInNode >= endInNodeold && namberold === namber) {
                startendInNode = endInNodeold;
              }

              endInNodeold = endInNode;
              namberold = namber;

              if (startInNode < endInNode) {
                const before = nodeValue.substring(startendInNode, startInNode);
                const middle = nodeValue.substring(startInNode, endInNode);
                const after = nodeValue.substring(endInNode);
                const mark = doc.createElement('mark');
                mark.textContent = middle;

                const afterNode = doc.createTextNode(after);
                node.nodeValue = before;
                node.parentNode.insertBefore(mark, node.nextSibling);
                node.parentNode.insertBefore(afterNode, mark.nextSibling);
                node = afterNode;
              }
            }
          }
          offset += nodeValue.length;
        });
      }

      highlightText();
    }


    // Основная функция поиска
    function searchText() {
      clearSearch();

      const query = document.getElementById('searchInput').value.trim();
      const content = document.getElementById('content');

      // Проверяем iframe на наличие PDF и показываем подсказку
      checkForPDFinIframes(content);
      const iframes = content.querySelectorAll('iframe');
      iframes[0].focus();
      if (!query) return;

      // Ищем в основном документе
      searchInDocument(document, query);

      // Ищем во всех iframe внутри #content
      iframes.forEach(iframe => {
        try {
          const doc = iframe.contentDocument || iframe.contentWindow.document;
          if (doc) {
            searchInDocument(doc, query);
          }
        } catch (e) {
          console.warn('Нет доступа к содержимому iframe для поиска:', e);
        }
      });
    }

// Функция проверки iframe на PDF контент
function checkForPDFinIframes(container) {
  const iframes = container.querySelectorAll('iframe');
  let pdfDetected = false;

  iframes.forEach(iframe => {
    try {
      const src = iframe.src || '';
      const dataSrc = iframe.getAttribute('data-src') || '';

      // Более надежные проверки для обнаружения PDF
      const isPDF =
        // Проверка по расширению файла в URL
        /\.pdf($|\?|#)/i.test(src) ||
        /\.pdf($|\?|#)/i.test(dataSrc) ||

        // Проверка blob URL с PDF
        (src.startsWith('blob:') && (src.includes('pdf') || src.includes('application/pdf'))) ||

        // Проверка contentDocument (если доступен)
        (iframe.contentDocument && (
          iframe.contentDocument.contentType === 'application/pdf' ||
          iframe.contentDocument.querySelector('embed[type="application/pdf"]') ||
          iframe.contentDocument.querySelector('object[type="application/pdf"]')
        )) ||

        // Проверка по заголовкам Content-Type (косвенная)
        (iframe.contentWindow && iframe.contentWindow.document &&
         iframe.contentWindow.document.contentType === 'application/pdf') ||

        // Проверка по наличию PDF.js viewer (популярный PDF рендерер)
        iframe.contentDocument?.querySelector('.pdfViewer') ||

        // Проверка по имени iframe или классам
        iframe.name.includes('pdf') ||
        iframe.className.includes('pdf');

      if (isPDF) {
        pdfDetected = true;
        console.log('Обнаружен PDF в iframe:', src || dataSrc);
      }

    } catch (e) {
      // Обрабатываем ошибки доступа к iframe (CORS политика)
      console.warn('Не удалось проверить iframe:', e);

      // Косвенная проверка для iframe с ограниченным доступом
      const src = iframe.src || '';
      if (src.includes('.pdf') || src.includes('blob:') && src.includes('pdf')) {
        pdfDetected = true;
        console.log('Предположительно PDF в заблокированном iframe:', src);
      }
    }
  });

  // Если найден PDF, показываем подсказку
  if (pdfDetected) {
    showPDFSearchHint();
    return true;
  }

  return false;
}


// Функция отображения подсказки для PDF
function showPDFSearchHint() {
  // Удаляем старую подсказку если она есть
  removePDFSearchHint();

  // Получаем элемент поля поиска
  const searchInput = document.getElementById('searchInput');
  if (!searchInput) return;

  // Получаем координаты поля поиска
  const rect = searchInput.getBoundingClientRect();

  // Создаем элемент для подсказки
  const hintElement = document.createElement('div');
  hintElement.id = 'pdf-search-hint';
  hintElement.innerHTML = 'Это .pdf файл лучше \n используйте Ctrl+F или 🔎';
  hintElement.style.cssText = `
    position: fixed;
    top: ${rect.bottom + window.scrollY + 10}px;
    left: ${rect.left + window.scrollX}px;
    background: rgba(0,0,0,0.8);
    color: white;
    padding: 10px 15px;
    border-radius: 5px;
    font-family: Arial, sans-serif;
    font-size: 20px;
    z-index: 9999;
    pointer-events: none;
    white-space: pre-line;
    max-width: 250px;
  `;

  document.body.appendChild(hintElement);

  // Автоматически скрываем через 5 секунд
  setTimeout(() => {
    removePDFSearchHint();
  }, 5000);
}

// Функция удаления подсказки
function removePDFSearchHint() {
  const existingHint = document.getElementById('pdf-search-hint');
  if (existingHint) {
    existingHint.remove();
  }
}
