#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { createCanvas, loadImage } from '../.dart_tool/pdf-render/node_modules/canvas/index.js';

const templatePageAssets = [
  'assets/template/cdx_pdf/page-01.png',
  'assets/template/cdx_pdf/page-02.png',
  'assets/template/cdx_pdf/page-03.png',
  'assets/template/cdx_pdf/page-04.png',
  'assets/template/cdx_pdf/page-05.png',
  'assets/template/cdx_pdf/page-06.png',
];

const outputDir = process.argv[2] ?? 'artifacts/pdf-field-map';

// Known clean "( )" sample from page 2. The detector uses this as a visual
// template, then scans all pages for similar option marks.
const optionTemplate = {
  asset: 'assets/template/cdx_pdf/page-02.png',
  x: 158,
  y: 106,
  width: 28,
  height: 20,
};

const threshold = 128;
const pdfPage = {
  width: 595.2755905511812,
  height: 841.8897637795277,
};

function isBlack(data, offset) {
  return data[offset] < threshold && data[offset + 1] < threshold && data[offset + 2] < threshold;
}

function imageToBinary(imageData) {
  const binary = new Uint8Array(imageData.width * imageData.height);
  for (let offset = 0, pixel = 0; offset < imageData.data.length; offset += 4, pixel++) {
    binary[pixel] = isBlack(imageData.data, offset) ? 1 : 0;
  }
  return binary;
}

function cropBinary(binary, imageWidth, imageHeight, crop) {
  const out = new Uint8Array(crop.width * crop.height);
  for (let y = 0; y < crop.height; y++) {
    for (let x = 0; x < crop.width; x++) {
      const sx = crop.x + x;
      const sy = crop.y + y;
      if (sx < 0 || sy < 0 || sx >= imageWidth || sy >= imageHeight) {
        continue;
      }
      out[y * crop.width + x] = binary[sy * imageWidth + sx];
    }
  }
  return out;
}

function connectedComponents(binary, width, height) {
  const seen = new Uint8Array(width * height);
  const components = [];
  const stack = [];

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const index = y * width + x;
      if (!binary[index] || seen[index]) {
        continue;
      }

      seen[index] = 1;
      stack.length = 0;
      stack.push(index);
      let minX = x;
      let maxX = x;
      let minY = y;
      let maxY = y;
      let count = 0;

      while (stack.length > 0) {
        const current = stack.pop();
        count++;
        const cx = current % width;
        const cy = Math.floor(current / width);
        minX = Math.min(minX, cx);
        maxX = Math.max(maxX, cx);
        minY = Math.min(minY, cy);
        maxY = Math.max(maxY, cy);

        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            if (dx === 0 && dy === 0) {
              continue;
            }
            const nx = cx + dx;
            const ny = cy + dy;
            if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
              continue;
            }
            const nextIndex = ny * width + nx;
            if (binary[nextIndex] && !seen[nextIndex]) {
              seen[nextIndex] = 1;
              stack.push(nextIndex);
            }
          }
        }
      }

      components.push({
        minX,
        maxX,
        minY,
        maxY,
        width: maxX - minX + 1,
        height: maxY - minY + 1,
        count,
      });
    }
  }

  return components;
}

function optionPairCandidates(components) {
  const narrowMarks = components.filter((component) => {
    const fillRatio = component.count / (component.width * component.height);
    return component.height >= 8 &&
      component.height <= 18 &&
      component.width >= 2 &&
      component.width <= 8 &&
      component.count >= 8 &&
      component.count <= 65 &&
      fillRatio >= 0.15 &&
      fillRatio <= 0.75;
  });

  const candidates = [];
  for (const left of narrowMarks) {
    for (const right of narrowMarks) {
      if (right.minX <= left.maxX) {
        continue;
      }
      const leftCenterY = (left.minY + left.maxY) / 2;
      const rightCenterY = (right.minY + right.maxY) / 2;
      const gap = right.minX - left.maxX;
      const pairWidth = right.maxX - left.minX + 1;
      const pairHeight = Math.max(left.maxY, right.maxY) - Math.min(left.minY, right.minY) + 1;
      if (
        Math.abs(leftCenterY - rightCenterY) <= 2.2 &&
        gap >= 5 &&
        gap <= 13 &&
        pairWidth >= 10 &&
        pairWidth <= 22 &&
        pairHeight >= 8 &&
        pairHeight <= 18
      ) {
        candidates.push({
          x: left.minX - 3,
          y: Math.min(left.minY, right.minY) - 3,
          width: optionTemplate.width,
          height: optionTemplate.height,
          raw: {
            left: { ...left },
            right: { ...right },
            gap,
            pairWidth,
            pairHeight,
          },
        });
      }
    }
  }
  return candidates;
}

function templateScore(pageBinary, pageWidth, pageHeight, templateBinary, candidate) {
  let bestScore = Number.POSITIVE_INFINITY;
  let bestOffset = { dx: 0, dy: 0 };
  const total = optionTemplate.width * optionTemplate.height;

  for (let dy = -2; dy <= 2; dy++) {
    for (let dx = -2; dx <= 2; dx++) {
      const crop = cropBinary(pageBinary, pageWidth, pageHeight, {
        x: candidate.x + dx,
        y: candidate.y + dy,
        width: optionTemplate.width,
        height: optionTemplate.height,
      });
      let diff = 0;
      for (let index = 0; index < total; index++) {
        if (crop[index] !== templateBinary[index]) {
          diff++;
        }
      }
      const score = diff / total;
      if (score < bestScore) {
        bestScore = score;
        bestOffset = { dx, dy };
      }
    }
  }

  return {
    score: bestScore,
    x: candidate.x + bestOffset.dx,
    y: candidate.y + bestOffset.dy,
    width: optionTemplate.width,
    height: optionTemplate.height,
  };
}

function nonMaximumSuppress(matches) {
  const kept = [];
  const sorted = [...matches].sort((a, b) => a.score - b.score);
  for (const match of sorted) {
    const centerX = match.x + match.width / 2;
    const centerY = match.y + match.height / 2;
    const duplicate = kept.some((other) => {
      const otherCenterX = other.x + other.width / 2;
      const otherCenterY = other.y + other.height / 2;
      return Math.abs(centerX - otherCenterX) <= 10 && Math.abs(centerY - otherCenterY) <= 8;
    });
    if (!duplicate) {
      kept.push(match);
    }
  }
  return kept.sort((a, b) => Math.round(a.y / 8) - Math.round(b.y / 8) || a.x - b.x);
}

async function loadBinary(assetPath) {
  const image = await loadImage(assetPath);
  const canvas = createCanvas(image.width, image.height);
  const context = canvas.getContext('2d');
  context.drawImage(image, 0, 0);
  const imageData = context.getImageData(0, 0, image.width, image.height);
  return {
    image,
    canvas,
    context,
    binary: imageToBinary(imageData),
    width: image.width,
    height: image.height,
  };
}

async function writeDebugImage(pageInfo, options, outputPath) {
  const canvas = createCanvas(pageInfo.width, pageInfo.height);
  const context = canvas.getContext('2d');
  context.drawImage(pageInfo.image, 0, 0);
  context.strokeStyle = '#d71920';
  context.fillStyle = '#d71920';
  context.lineWidth = 2;
  context.font = '10px Arial';
  for (const option of options) {
    context.strokeRect(option.x, option.y, option.width, option.height);
    context.fillText(option.id, option.x, Math.max(10, option.y - 3));
  }
  await fs.writeFile(outputPath, canvas.toBuffer('image/png'));
}

async function main() {
  await fs.mkdir(outputDir, { recursive: true });

  const templatePage = await loadBinary(optionTemplate.asset);
  const optionTemplateBinary = cropBinary(
    templatePage.binary,
    templatePage.width,
    templatePage.height,
    optionTemplate,
  );

  const fieldMap = {
    generatedAt: new Date().toISOString(),
    detector: 'tools/pdf_field_detector.mjs',
    pageWidth: templatePage.width,
    pageHeight: templatePage.height,
    optionTemplate,
    pages: [],
  };

  for (let pageIndex = 0; pageIndex < templatePageAssets.length; pageIndex++) {
    const asset = templatePageAssets[pageIndex];
    const page = await loadBinary(asset);
    const components = connectedComponents(page.binary, page.width, page.height);
    const candidates = pageIndex === 0 ? [] : optionPairCandidates(components);
    const scored = candidates
      .map((candidate) =>
        templateScore(page.binary, page.width, page.height, optionTemplateBinary, candidate),
      )
      .filter((candidate) => candidate.score <= 0.12 && candidate.y < page.height - 90);
    const options = nonMaximumSuppress(scored).map((option, index) => ({
      id: `p${String(pageIndex + 1).padStart(2, '0')}_option_${String(index + 1).padStart(3, '0')}`,
      x: Math.round(option.x),
      y: Math.round(option.y),
      width: option.width,
      height: option.height,
      centerX: Number((option.x + option.width / 2).toFixed(1)),
      centerY: Number((option.y + option.height / 2).toFixed(1)),
      pdfX: Number(((option.x * pdfPage.width) / page.width).toFixed(2)),
      pdfY: Number(((option.y * pdfPage.height) / page.height).toFixed(2)),
      pdfCenterX: Number((((option.x + option.width / 2) * pdfPage.width) / page.width).toFixed(2)),
      pdfCenterY: Number((((option.y + option.height / 2) * pdfPage.height) / page.height).toFixed(2)),
      score: Number(option.score.toFixed(4)),
    }));

    const pageName = `page-${String(pageIndex + 1).padStart(2, '0')}`;
    fieldMap.pages.push({
      page: pageIndex + 1,
      asset,
      optionCount: options.length,
      options,
    });
    await writeDebugImage(
      page,
      options,
      path.join(outputDir, `${pageName}-detected-options.png`),
    );
    console.log(`${pageName}: detected ${options.length} option marks`);
  }

  await fs.writeFile(
    path.join(outputDir, 'detected-option-centers.json'),
    `${JSON.stringify(fieldMap, null, 2)}\n`,
  );
  console.log(`Wrote ${path.join(outputDir, 'detected-option-centers.json')}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
