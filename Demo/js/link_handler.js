  // Получаем параметр 'doc' из URL
  function getQueryParam(name) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(name);
  }
  const filePath = getQueryParam('doc'); // например, "/documents/myfile.pdf"
  console.log('Текущий файл внутри iframe:', filePath);
  if (filePath) {
    // Проверяем расширение файла
    const lowerPath = filePath.toLowerCase();
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.ico'];
    const isImage = imageExtensions.some(ext => lowerPath.endsWith(ext));
    const isPDF = lowerPath.endsWith('.pdf');

    // if (isImage) {
    //   // const viewerUrl = `../scripts/spwpic.php?func=mscale&qmsc=${encodeURIComponent(filePath)}`;
    //   const viewerUrl = `../scripts/spwpic.html?file=${encodeURIComponent(filePath)}`;
    //   document.getElementById('docFrame').src = viewerUrl;
    // } else if (isPDF) {
    //   const viewerUrl = `../pdf.js/web/viewer.html?file=${encodeURIComponent(filePath)}`;
    //   document.getElementById('docFrame').src = viewerUrl;
    // } else {
    //   document.getElementById('docFrame').src = filePath;
    // }

    if (isImage) {
        const scriptDir = document.currentScript.src.replace(/\/[^/]+$/, '/directories');
        // const viewerUrl = `${scriptDir.replace('/js/directories', '/scripts/')}spwpic.php?func=mscale&qmsc=${encodeURIComponent(filePath)}`;
        const viewerUrl = `${scriptDir.replace('/js/directories', '/scripts/')}spwpic.html?file=${encodeURIComponent(filePath)}`;
        document.getElementById('docFrame').src = viewerUrl;
    } else if (isPDF) {
        const scriptDir = document.currentScript.src.replace(/\/[^/]+$/, '/directories');
        const viewerUrl = `${scriptDir.replace('/js/directories', '/pdf.js/web/')}viewer.html?file=${encodeURIComponent(filePath)}`;
        document.getElementById('docFrame').src = viewerUrl;
    } else {
        document.getElementById('docFrame').src = filePath;
    }
  }
