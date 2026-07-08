// URL относительно директории скрипта
const scriptDir = document.currentScript.src.replace(/\/[^/]+$/, '/directories');
document.addEventListener('DOMContentLoaded', () => {
document.querySelectorAll('a[href]').forEach(link => {
link.addEventListener('click', e => {
e.preventDefault();

let href = link.getAttribute('href');

// Создаём абсолютную ссылку: если href относительный, он будет преобразован
const filePath = new URL(href, window.location.href).href;

  console.log('linkUrl iframe:', filePath);
  if (filePath) {
    // Проверяем расширение файла
    const lowerPath = filePath.toLowerCase();
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.ico'];
    const isImage = imageExtensions.some(ext => lowerPath.endsWith(ext));
    const isPDF = lowerPath.endsWith('.pdf');

    // if (isImage) {
    //   // const viewerUrl = `../scripts/spwpic.php?func=mscale&qmsc=${encodeURIComponent(filePath)}`;
    //   const viewerUrl = `../../scripts/spwpic.html?file=${encodeURIComponent(filePath)}`;
    //   window.location.href = viewerUrl;
    // } else if (isPDF) {
    //   const viewerUrl = `../../pdf.js/web/viewer.html?file=${encodeURIComponent(filePath)}`;
    //   window.location.href = viewerUrl;
    // } else {
    //   window.location.href = filePath;
    // }

    if (isImage) {
      // const viewerUrl = `${scriptDir.replace('/js/directories', '/scripts/')}spwpic.php?func=mscale&qmsc=${encodeURIComponent(filePath)}`;
      const viewerUrl = `${scriptDir.replace('/js/directories', '/scripts/')}spwpic.html?file=${encodeURIComponent(filePath)}`;
      window.location.href = viewerUrl;
    } else if (isPDF) {
      const viewerUrl = `${scriptDir.replace('/js/directories', '/pdf.js/web/')}viewer.html?file=${encodeURIComponent(filePath)}`;
      window.location.href = viewerUrl;
    } else {
      window.location.href = filePath;
    }

  }

});
});
});
