import { expect, type Locator, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';

const screenshotDir = process.env.SCREENSHOT_DIR ?? 'screenshots';

export async function openFlutterApp(page: Page, path = '/'): Promise<void> {
  await page.goto(path);
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached' });
  await placeholder.dispatchEvent('click');
  await expect(page.locator('flt-semantics').first()).toBeAttached();
}

export async function typeInto(page: Page, label: string, text: string): Promise<void> {
  const field = page.getByRole('textbox', { name: label });
  await expect(async () => {
    await field.click();
    await page.waitForFunction(
      () => document.activeElement?.tagName === 'INPUT' || document.activeElement?.tagName === 'TEXTAREA',
    );
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.type(text, { delay: 20 });
    await expect(page.locator(':focus')).toHaveValue(text, { timeout: 1000 });
  }).toPass({ timeout: 15_000 });
}

export function button(page: Page, name: string | RegExp): Locator {
  return page.getByRole('button', { name });
}

export function text(page: Page, value: string | RegExp): Locator {
  return page.getByText(value).or(page.getByLabel(value)).first();
}

export function allText(page: Page, value: string | RegExp): Locator {
  return page.getByText(value).or(page.getByLabel(value));
}

export async function scrollDown(page: Page, times = 1): Promise<void> {
  for (let i = 0; i < times; i++) {
    await page.mouse.move(200, 500);
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(300);
  }
}

export async function screenshot(page: Page, name: string): Promise<void> {
  mkdirSync(screenshotDir, { recursive: true });
  await page.mouse.move(1, 1);
  await page.waitForTimeout(600);
  await page.screenshot({ path: join(screenshotDir, `${name}.png`) });
}

export async function semanticTexts(page: Page, pattern: RegExp): Promise<string[]> {
  const texts = await page
    .locator('flt-semantics')
    .evaluateAll((nodes) => nodes.map((node) => node.getAttribute('aria-label') ?? node.textContent ?? ''));
  return texts.filter((value) => pattern.test(value));
}

export async function openTab(page: Page, name: string): Promise<void> {
  await page
    .getByRole('tab', { name })
    .or(page.getByRole('button', { name, exact: true }))
    .first()
    .click();
}

export async function scrollUp(page: Page, times = 1): Promise<void> {
  for (let i = 0; i < times; i++) {
    await page.mouse.move(200, 400);
    await page.mouse.wheel(0, -600);
    await page.waitForTimeout(200);
  }
}

export async function scrollUntilVisible(page: Page, target: Locator, attempts = 10): Promise<void> {
  for (let i = 0; i < attempts && !(await target.isVisible()); i++) {
    await scrollDown(page);
  }
  await expect(target).toBeVisible();
}
