import { expect, test } from '@playwright/test';

test('renders the 3D universe map and classifies a pasted tool', async ({ page }) => {
  await page.addInitScript(() => window.localStorage.clear());
  await page.goto('/');

  await expect(page.getByTestId('ai-tool-universe-map')).toBeVisible();
  await expect(page.getByText('Universe controls')).toBeVisible();
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

  const box = await canvas.boundingBox({ timeout: 10_000 });
  expect(box?.width ?? 0).toBeGreaterThan(300);
  expect(box?.height ?? 0).toBeGreaterThan(300);
});
