const rasterImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
  '.ico',
};

const svgExtension = '.svg';

bool isSvgFile(String fileName) {
  return fileName.toLowerCase().endsWith(svgExtension);
}

bool isRasterImageFile(String fileName) {
  final lower = fileName.toLowerCase();
  return rasterImageExtensions.any(lower.endsWith);
}

bool isImageFile(String fileName) {
  return isRasterImageFile(fileName) || isSvgFile(fileName);
}

const fontExtensions = {'.ttf', '.otf', '.woff', '.woff2'};

bool isFontFile(String fileName) {
  final lower = fileName.toLowerCase();
  return fontExtensions.any(lower.endsWith);
}

const previewableFontExtensions = {'.ttf', '.otf'};

bool isPreviewableFontFile(String fileName) {
  final lower = fileName.toLowerCase();
  return previewableFontExtensions.any(lower.endsWith);
}

bool isProjectMediaFile(String fileName) {
  return isImageFile(fileName) || isFontFile(fileName);
}

String? fileTypeLabel(String fileName) {
  if (isSvgFile(fileName)) return 'SVG';
  if (isRasterImageFile(fileName)) return 'Image';
  if (isFontFile(fileName)) return 'Font';
  return null;
}
