import { expect, test } from '@playwright/test';

test('renders the 3D universe map and classifies a pasted tool', async ({ page }) => {
  await page.addInitScript(() => window.localStorage.clear());
  await page.goto('/');

  await expect(page.getByTestId('ai-tool-universe-map')).toBeVisible();
  await expect(page.getByText('Universe lens')).toBeVisible();
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas) return false;
    const box = canvas.getBoundingClientRect();
    return box.width > 300 && box.height > 300;
  }, null, { timeout: 20_000 });
  const canvas = page.locator('canvas').first();
  await expect(page.getByText('Founder OS').first()).toBeVisible();

  const intake = page.getByPlaceholder('Tool name or URL');
  await intake.fill('https://buffer.com/');
  await page.getByTitle('Classify tool').click();

  await expect(page.getByRole('heading', { name: 'Buffer' })).toBeVisible();
  await expect(page.getByText('Distribution & Social Ops').first()).toBeVisible();
  await page.getByRole('button', { name: /Same stage/i }).click();
  await expect(page.getByRole('button', { name: /Same stage/i }).first()).toBeVisible();
  await page.getByRole('button', { name: /Same group/i }).click();
  await expect(page.getByRole('button', { name: /Same group/i }).first()).toBeVisible();
  await page.getByRole('button', { name: /Atlas map/i }).click();
  await expect(page.getByRole('button', { name: /Atlas map/i }).first()).toBeVisible();
  await page.getByRole('button', { name: /Focus map/i }).click();
  await expect(page.getByRole('button', { name: /Focus map/i }).first()).toBeVisible();

  await page.locator('aside').first().getByRole('button', { name: /Design/ }).first().click();
  await expect(page.getByText(/Pocket world · Design/).first()).toBeVisible();
  await expect(page.locator('.universe-pocket-readout')).toContainText('Design');
  await expect(page.getByText('Cluster inspector')).toBeVisible();
  await expect(page.getByText('Design & Product UI').first()).toBeVisible();
  await expect(page.getByRole('button', { name: /Same group/i }).first()).toBeVisible();
  await expect(page.getByRole('button', { name: /Context map/i }).first()).toBeVisible();

  await page.getByPlaceholder('Cursor, video, skills...').fill('cursor');
  await expect(page.getByText('Scan results')).toBeVisible();
  await page.locator('aside').first().getByRole('button', { name: /Cursor/i }).first().click();
  await expect(page.getByRole('heading', { name: 'Cursor' })).toBeVisible();
  await expect(page.getByText('Workflow').first()).toBeVisible();

  const box = await canvas.boundingBox({ timeout: 10_000 });
  expect(box?.width ?? 0).toBeGreaterThan(300);
  expect(box?.height ?? 0).toBeGreaterThan(300);
});

test('desktop hover makes the focused tool unambiguous', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name.includes('mobile'), 'Hover focus is a desktop pointer interaction.');

  await page.addInitScript(() => window.localStorage.clear());
  await page.goto('/');
  await page.getByTestId('ai-tool-universe-map').waitFor({ state: 'visible' });

  await page.getByPlaceholder('Tool name or URL').fill('https://buffer.com/');
  await page.getByTitle('Classify tool').click();
  await page.getByRole('heading', { name: 'Buffer' }).waitFor({ state: 'visible' });

  await page.getByRole('button', { name: 'Inspect Buffer' }).hover();

  await expect(page.locator('.universe-focus-readout')).toContainText('Buffer');
  await expect(page.locator('.universe-focus-readout')).toContainText('connected nodes in focus');
});
