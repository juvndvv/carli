import { expect, test } from '@playwright/test';

test('theme toggle cycles light, dark and system and persists across reloads', async ({ page }) => {
  await page.goto('/finanzas');
  const html = page.locator('html');
  const toggle = page.getByRole('button', { name: /^Cambiar tema/ });

  await expect(toggle).toHaveAccessibleName(/actual: (Claro|Oscuro|Sistema)\)$/);
  for (let attempt = 0; attempt < 3; attempt++) {
    const name = (await toggle.getAttribute('aria-label')) ?? '';
    if (name.endsWith('Claro)')) {
      break;
    }
    await toggle.click();
    await expect(toggle).not.toHaveAccessibleName(name);
  }
  await expect(html).toHaveAttribute('data-theme', 'light');
  const lightBackground = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);

  const saved = page.waitForResponse(
    (response) =>
      response.url().endsWith('/api/v1/me/preferences') && response.ok() && /"dark"/.test(response.request().postData() ?? ''),
  );
  await toggle.click();
  await saved;
  await expect(html).toHaveAttribute('data-theme', 'dark');
  await expect(toggle).toHaveAccessibleName('Cambiar tema (actual: Oscuro)');
  const darkBackground = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  expect(darkBackground).not.toBe(lightBackground);

  const session = page.waitForResponse((response) => response.url().endsWith('/api/v1/me') && response.ok());
  await page.reload();
  await session;
  await expect(page.getByRole('button', { name: /^Cambiar tema/ })).toHaveAccessibleName('Cambiar tema (actual: Oscuro)');
  await expect(html).toHaveAttribute('data-theme', 'dark');

  await page.getByRole('button', { name: /^Cambiar tema/ }).click();
  await expect(html).not.toHaveAttribute('data-theme', /.+/);
  await expect(page.getByRole('button', { name: /^Cambiar tema/ })).toHaveAccessibleName('Cambiar tema (actual: Sistema)');
});
