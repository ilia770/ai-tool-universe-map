import { expect, test, type Page } from '@playwright/test';

const internalCopyPattern = /rule-based|persisted relations|VITE_|Logo\.dev|local SVG fallback|Import custom tools JSON|Local node|Liquid Glass Intake/i;

async function openUniverse(page: Page) {
  await page.addInitScript(() => window.localStorage.clear());
  await page.goto('/');

  await expect(page.getByTestId('ai-tool-universe-map')).toBeVisible();
  await expect(page.getByText('Universe lens')).toBeVisible();
  await expect(page.getByText('3D view unavailable')).toHaveCount(0);
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas) return false;
    const box = canvas.getBoundingClientRect();
    return box.width > 300 && box.height > 300;
  }, null, { timeout: 20_000 });
}

async function classifyTool(page: Page, value: string) {
  const input = page.getByPlaceholder('Tool name or URL');
  await input.fill(value);
  await input.press('Enter');
}

async function wheelOutFromCanvas(page: Page) {
  const canvasBox = await page.locator('canvas').first().boundingBox({ timeout: 10_000 });
  expect(canvasBox).not.toBeNull();

  await page.mouse.move(
    (canvasBox?.x ?? 0) + (canvasBox?.width ?? 0) * 0.5,
    (canvasBox?.y ?? 0) + (canvasBox?.height ?? 0) * 0.42,
  );

  for (let step = 0; step < 5; step += 1) {
    await page.mouse.wheel(0, 1600);
    await page.waitForTimeout(180);
  }
}

async function visibleLabelRects(page: Page) {
  return page.locator('[data-universe-node-label].is-visible').evaluateAll((nodes) =>
    nodes
      .map((node) => {
        const element = node as HTMLElement;
        const rect = element.getBoundingClientRect();
        const style = window.getComputedStyle(element);
        return {
          id: element.dataset.toolId ?? '',
          focus: element.dataset.focusLabel === 'true',
          opacity: Number.parseFloat(style.opacity || '0'),
          width: rect.width,
          height: rect.height,
          left: rect.left,
          right: rect.right,
          top: rect.top,
          bottom: rect.bottom,
        };
      })
      .filter((rect) => rect.opacity > 0.5 && rect.width > 8 && rect.height > 8),
  );
}

function overlapRatio(
  a: Awaited<ReturnType<typeof visibleLabelRects>>[number],
  b: Awaited<ReturnType<typeof visibleLabelRects>>[number],
) {
  const width = Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left));
  const height = Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
  const area = width * height;
  if (area === 0) return 0;
  const smallerArea = Math.min(a.width * a.height, b.width * b.height);
  return smallerArea > 0 ? area / smallerArea : 0;
}

test('keeps public UI free of implementation copy', async ({ page }) => {
  await openUniverse(page);

  await expect(page.locator('body')).not.toContainText(internalCopyPattern);
  await expect(page.getByText('Add service')).toBeVisible();
});

test('mobile and tablet expose the selected-service panel', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name.includes('desktop'), 'Mobile/tablet layout regression only.');

  await openUniverse(page);

  const panel = page.getByTestId('tool-detail-panel');
  await expect(panel.getByRole('heading', { name: 'Founder OS' })).toBeVisible();

  const box = await panel.boundingBox();
  const viewport = page.viewportSize();
  expect(box).not.toBeNull();
  expect(viewport).not.toBeNull();
  expect(box?.height ?? 0).toBeGreaterThan(220);
  expect(box?.y ?? Number.POSITIVE_INFINITY).toBeLessThan(viewport?.height ?? 0);
});

test('renders the 3D universe map and classifies a pasted tool', async ({ page }) => {
  await openUniverse(page);

  const canvas = page.locator('canvas').first();
  await expect(page.getByText('Founder OS').first()).toBeVisible();

  await classifyTool(page, 'https://buffer.com/');

  await expect(page.getByRole('heading', { name: 'Buffer' })).toBeVisible();
  await expect(page.getByText('Distribution & Social Ops').first()).toBeVisible();
  const detailsPanel = page.getByTestId('tool-detail-panel');
  await expect(detailsPanel.getByTestId('connected-because')).toBeVisible();

  const box = await canvas.boundingBox({ timeout: 10_000 });
  expect(box?.width ?? 0).toBeGreaterThan(300);
  expect(box?.height ?? 0).toBeGreaterThan(300);
});

test('details panel relation lens can switch views', async ({ page }) => {
  test.setTimeout(90_000);
  await openUniverse(page);

  await classifyTool(page, 'https://buffer.com/');
  await page.getByRole('heading', { name: 'Buffer' }).waitFor({ state: 'visible' });

  const detailsPanel = page.getByTestId('tool-detail-panel');
  await detailsPanel.getByTestId('relation-lens-details').locator('summary').click();
  await detailsPanel.getByTestId('relation-lens-stage').scrollIntoViewIfNeeded();
  await detailsPanel.getByTestId('relation-lens-stage').click();
  await expect(detailsPanel.getByTestId('relation-lens-stage')).toHaveClass(/border-fuchsia-200/);
  await detailsPanel.getByTestId('relation-lens-category').click();
  await expect(detailsPanel.getByTestId('relation-lens-category')).toHaveClass(/border-fuchsia-200/);
});

test('category filter opens a pocket world', async ({ page }) => {
  test.setTimeout(90_000);
  await openUniverse(page);

  const designChip = page.getByTestId('lens-category-design');
  await designChip.scrollIntoViewIfNeeded();
  await expect(designChip).toBeVisible();
  await designChip.click();
  await expect(designChip).toHaveClass(/bg-white\/15/);
  await expect(page.getByText(/Pocket world\s*·\s*Design/).first()).toBeVisible({ timeout: 15_000 });
  await expect(page.locator('.universe-pocket-readout')).toContainText('Design');
  await expect(page.getByText('Nearby in group')).toBeVisible();
  await expect(page.getByTestId('tool-detail-panel').getByText('Design & Product UI').first()).toBeVisible();
  await expect(page.getByRole('button', { name: 'All stages' })).toBeVisible();
});

test('wheel zoom exits an open pocket world', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name.includes('mobile'), 'Wheel zoom is a desktop/tablet camera interaction.');
  test.setTimeout(90_000);

  await openUniverse(page);

  const designChip = page.getByTestId('lens-category-design');
  await designChip.scrollIntoViewIfNeeded();
  await designChip.click();

  await expect(page.getByText(/Pocket world\s*·\s*Design/).first()).toBeVisible({ timeout: 15_000 });
  await expect(page.locator('.universe-pocket-readout')).toContainText('Design');

  await page.waitForTimeout(1_800);
  await wheelOutFromCanvas(page);

  await expect(page.locator('.universe-pocket-readout')).toHaveCount(0, { timeout: 12_000 });
  await expect(page.getByText(/All groups\s*·\s*All workflow stages/).first()).toBeVisible();
  await expect(page.getByText('Scroll-zoom into a ring to open its pocket world')).toBeVisible();
});

test('search enter focuses the first matching tool', async ({ page }) => {
  await openUniverse(page);

  const search = page.getByPlaceholder('Cursor, video, skills...');
  await search.fill('cursor');
  await expect(page.getByText('Scan results')).toBeVisible();
  await search.press('Enter');
  await expect(page.getByRole('heading', { name: 'Cursor' })).toBeVisible();
  await expect(page.getByText('Workflow').first()).toBeVisible();
});

test('desktop hover makes the focused tool unambiguous', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name.includes('mobile'), 'Hover focus is a desktop pointer interaction.');
  test.setTimeout(90_000);

  await openUniverse(page);

  await classifyTool(page, 'https://buffer.com/');
  await page.getByRole('heading', { name: 'Buffer' }).waitFor({ state: 'visible' });

  const bufferNode = page.getByRole('button', { name: 'Inspect Buffer' });
  await expect(bufferNode).toBeVisible({ timeout: 15_000 });
  await bufferNode.hover({ force: true });

  await expect(page.locator('.universe-focus-readout')).toContainText('Buffer');
  await expect(page.locator('.universe-focus-readout')).toContainText('connected nodes in focus');

  await expect(page.locator('[data-universe-node-label].is-focus[title="Buffer"]')).toBeVisible();
  await page.waitForTimeout(650);

  const rects = await visibleLabelRects(page);
  const focusRect = rects.find((rect) => rect.focus);
  expect(focusRect).toBeTruthy();
  expect(rects.length).toBeLessThanOrEqual(8);

  const nonFocusRects = rects.filter((rect) => !rect.focus);
  const worstNonFocusOverlap = nonFocusRects.reduce((max, rect, index) => {
    const overlaps = nonFocusRects.slice(index + 1).map((other) => overlapRatio(rect, other));
    return Math.max(max, 0, ...overlaps);
  }, 0);
  expect(worstNonFocusOverlap).toBeLessThan(0.38);

  const worstFocusOverlap = nonFocusRects.reduce((max, rect) => Math.max(max, overlapRatio(focusRect!, rect)), 0);
  expect(worstFocusOverlap).toBeLessThan(0.2);
});
