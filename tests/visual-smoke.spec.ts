import { expect, test, type Page } from '@playwright/test';

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

test('renders the 3D universe map and classifies a pasted tool', async ({ page }) => {
  await openUniverse(page);

  const canvas = page.locator('canvas').first();
  await expect(page.getByText('Founder OS').first()).toBeVisible();

  await page.getByPlaceholder('Tool name or URL').fill('https://buffer.com/');
  await page.getByTitle('Classify tool').click();

  await expect(page.getByRole('heading', { name: 'Buffer' })).toBeVisible();
  await expect(page.getByText('Distribution & Social Ops').first()).toBeVisible();
  const detailsPanel = page.getByTestId('tool-detail-panel');
  await expect(detailsPanel.getByTestId('connected-because')).toBeVisible();

  const box = await canvas.boundingBox({ timeout: 10_000 });
  expect(box?.width ?? 0).toBeGreaterThan(300);
  expect(box?.height ?? 0).toBeGreaterThan(300);
});

test('details panel relation lens can switch views', async ({ page }) => {
  await openUniverse(page);

  await page.getByPlaceholder('Tool name or URL').fill('https://buffer.com/');
  await page.getByTitle('Classify tool').click();
  await page.getByRole('heading', { name: 'Buffer' }).waitFor({ state: 'visible' });

  const detailsPanel = page.getByTestId('tool-detail-panel');
  await detailsPanel.getByTestId('relation-lens-stage').scrollIntoViewIfNeeded();
  await detailsPanel.getByTestId('relation-lens-stage').click();
  await expect(detailsPanel.getByTestId('relation-lens-stage')).toHaveClass(/border-fuchsia-200/);
  await detailsPanel.getByTestId('relation-lens-category').click();
  await expect(detailsPanel.getByTestId('relation-lens-category')).toHaveClass(/border-fuchsia-200/);
});

test('category filter opens a pocket world', async ({ page }) => {
  await openUniverse(page);

  const designChip = page.getByTestId('lens-category-design');
  await designChip.scrollIntoViewIfNeeded();
  await expect(designChip).toBeVisible();
  await designChip.click();
  await expect(designChip).toHaveClass(/bg-white\/15/);
  await expect(page.getByText(/Pocket world\s*·\s*Design/).first()).toBeVisible({ timeout: 15_000 });
  await expect(page.locator('.universe-pocket-readout')).toContainText('Design');
  await expect(page.getByText('Nearby in group')).toBeVisible();
  await expect(page.getByText('Design & Product UI').first()).toBeVisible();
  await expect(page.getByText('All stages').first()).toBeVisible();
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

  await openUniverse(page);

  await page.getByPlaceholder('Tool name or URL').fill('https://buffer.com/');
  await page.getByTitle('Classify tool').click();
  await page.getByRole('heading', { name: 'Buffer' }).waitFor({ state: 'visible' });

  await page.getByRole('button', { name: 'Inspect Buffer' }).dispatchEvent('mouseover');

  await expect(page.locator('.universe-focus-readout')).toContainText('Buffer');
  await expect(page.locator('.universe-focus-readout')).toContainText('connected nodes in focus');
});
