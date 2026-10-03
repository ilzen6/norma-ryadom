import AxeBuilder from '@axe-core/playwright';
import { expect, test, type APIRequestContext, type Page } from '@playwright/test';
import { readFileSync } from 'node:fs';

const username = process.env.ADMIN_USERNAME ?? 'admin';
const password = process.env.ADMIN_PASSWORD ?? '';

async function login(page: Page): Promise<void> {
  await page.goto('/admin');
  await expect(page).toHaveURL(/\/admin\/login$/);
  await page.getByLabel('Логин').fill(username);
  await page.getByLabel('Пароль').fill(password);
  await page.getByRole('button', { name: 'Войти' }).click();
  await expect(page.getByRole('heading', { name: 'Обзор' })).toBeVisible();
}

async function expectAccessible(page: Page): Promise<void> {
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']).analyze();
  expect(results.violations.map((violation) => `${violation.id}: ${violation.help}`)).toEqual([]);
}

const moscowCity = { lat: 55.7495, lon: 37.5374 };
const burgerKing = { name: 'Бургер Кинг', address: 'Пресненская наб., 2' };
const porkDish = 'Ангус шеф';

async function venueId(request: APIRequestContext): Promise<number> {
  const response = await request.get(`/api/v1/venues?lat=${moscowCity.lat}&lon=${moscowCity.lon}&radius=500`);
  expect(response.ok()).toBeTruthy();
  const body = (await response.json()) as { venues: { venue: { id: number; name: string; address: string } }[] };
  const venue = body.venues.find(
    (entry) => entry.venue.name === burgerKing.name && entry.venue.address === burgerKing.address,
  );
  if (!venue) throw new Error(`В демо-данных нет заведения «${burgerKing.name}, ${burgerKing.address}»`);
  return venue.venue.id;
}

test.beforeAll(() => {
  if (!password) throw new Error('Задайте ADMIN_PASSWORD для E2E-тестов админки');
});

test('без входа админка недоступна, неверный пароль отклоняется', async ({ page }) => {
  await page.goto('/admin/chains');
  await expect(page).toHaveURL(/\/admin\/login$/);
  await page.getByLabel('Логин').fill(username);
  await page.getByLabel('Пароль').fill('wrong-password');
  await page.getByRole('button', { name: 'Войти' }).click();
  await expect(page.getByRole('alert')).toHaveText('Неверный логин или пароль');
  await expectAccessible(page);
});

test('администратор заводит сеть, загружает меню и точки, видит ошибки CSV', async ({ page, request }) => {
  await login(page);
  await expectAccessible(page);
  await page.screenshot({ path: 'screenshots/admin-01-dashboard.png', fullPage: true });

  await page.getByRole('link', { name: 'Сети и меню' }).first().click();
  const chainName = `E2E Столовая ${Date.now()}`;
  await page.getByLabel('Название').fill(chainName);
  await page.getByLabel('Страница с КБЖУ сети').fill('https://stolovaya.example/kbju');
  await page.getByRole('button', { name: 'Создать' }).click();
  await expect(page.getByRole('heading', { name: chainName })).toBeVisible();

  await page.getByLabel('Файл меню').setInputFiles('fixtures/broken-menu.csv');
  await page.getByRole('button', { name: 'Загрузить меню' }).click();
  const errors = page.getByRole('alert');
  await expect(errors).toContainText('Файл не принят, данные не изменены');
  await expect(errors).toContainText('Неизвестная категория');
  await expect(errors).toContainText('Ожидается число');
  await expect(errors).toContainText('Неизвестный тег');
  await page.screenshot({ path: 'screenshots/admin-02-csv-errors.png', fullPage: true });

  await page.getByLabel('Файл меню').setInputFiles('fixtures/e2e-chain-menu.csv');
  await page.getByRole('button', { name: 'Загрузить меню' }).click();
  await expect(page.getByTestId('upserted')).toHaveText('3');
  await page.getByLabel('Файл точек').setInputFiles('fixtures/e2e-chain-venues.csv');
  await page.getByRole('button', { name: 'Загрузить точки' }).click();
  await expect(page.getByTestId('venue-table')).toContainText('Столовая E2E, Невский');
  await expect(page.getByTestId('menu-table')).toContainText('Котлета индейки с гречкой');
  await expectAccessible(page);
  await page.screenshot({ path: 'screenshots/admin-03-chain.png', fullPage: true });

  const nearby = await request.get('/api/v1/venues?lat=59.9357&lon=30.3256&radius=200');
  const body = (await nearby.json()) as { venues: { venue: { name: string }; hasMenu: boolean }[] };
  expect(body.venues.find((venue) => venue.venue.name === 'Столовая E2E, Невский')?.hasMenu).toBe(true);
});

test('модератор видит фото меню с распознанным текстом и переносит блюда в меню', async ({ page, request }) => {
  const venue = await venueId(request);
  const upload = await request.post(`/api/v1/venues/${venue}/menu-photos`, {
    multipart: {
      photo: { name: 'menu.png', mimeType: 'image/png', buffer: readFileSync('fixtures/menu-photo.png') },
    },
  });
  expect(upload.status()).toBe(202);
  const { submissionId } = (await upload.json()) as { submissionId: number };

  await login(page);
  await page.getByRole('link', { name: 'Модерация фото' }).click();
  await expect(page.getByTestId('submission-table')).toContainText(String(submissionId));
  await page.getByRole('link', { name: String(submissionId), exact: true }).click();
  await expect(async () => {
    await page.reload();
    await expect(page.getByTestId('ocr-text')).toContainText('Шаурма', { timeout: 1_000 });
  }).toPass({ timeout: 60_000 });
  await expect(page.getByRole('img', { name: 'Фото меню от пользователя' })).toBeVisible();
  await expectAccessible(page);
  await page.screenshot({ path: 'screenshots/admin-04-moderation.png', fullPage: true });

  const dishName = `Шаурма куриная ${submissionId}`;
  await page
    .getByLabel('Строки меню')
    .fill(
      `name;category;portion_g;kcal;protein_g;fat_g;carbs_g;price_rub;tags\n${dishName};main;300;520;32;22;48;320;chicken,gluten`,
    );
  await page.getByRole('button', { name: 'Подтвердить и добавить в меню' }).click();
  await expect(page.getByTestId('approved-items')).toHaveText('1');

  const menu = await request.get(`/api/v1/venues/${venue}/menu`);
  const items = ((await menu.json()) as { items: { name: string; source: { kind: string } }[] }).items;
  expect(items.find((item) => item.name === dishName)?.source.kind).toBe('B');
});

test('после трёх жалоб блюдо уходит на перепроверку, модератор исправляет цифры', async ({ page, request }) => {
  const venue = await venueId(request);
  const menu = await request.get(`/api/v1/venues/${venue}/menu`);
  const items = ((await menu.json()) as { items: { id: number; name: string }[] }).items;
  const item = items.find((entry) => entry.name === porkDish);
  if (!item) throw new Error(`В меню нет блюда «${porkDish}»`);
  const repeated = await request.post(`/api/v1/items/${item.id}/reports`, {
    data: { reason: 'Повтор от того же человека' },
    headers: { 'X-Forwarded-For': '203.0.113.10' },
  });
  expect(repeated.status()).toBe(204);
  const reasons = ['На стенде другие цифры', 'Калорий явно больше', 'Порция меньше заявленной'];
  for (const [index, reason] of reasons.entries()) {
    const report = await request.post(`/api/v1/items/${item.id}/reports`, {
      data: { reason },
      headers: { 'X-Forwarded-For': `203.0.113.${10 + index}` },
    });
    expect(report.status()).toBe(204);
  }
  const afterReports = await request.get(`/api/v1/venues/${venue}/menu`);
  const visible = ((await afterReports.json()) as { items: { id: number }[] }).items.map((entry) => entry.id);
  expect(visible).not.toContain(item.id);

  await login(page);
  await page.getByRole('link', { name: 'Жалобы' }).click();
  const card = page.locator(`[data-item-id="${item.id}"]`);
  await expect(card).toContainText('Калорий явно больше');
  await expect(card).toContainText('Повтор от того же человека');
  await expect(card).not.toContainText('На стенде другие цифры');
  await expectAccessible(page);
  await page.screenshot({ path: 'screenshots/admin-05-reviews.png', fullPage: true });
  await card.getByLabel('Ккал').fill('300');
  await card.getByLabel('Белки').fill('20');
  await card.getByLabel('Жиры').fill('10');
  await card.getByLabel('Углеводы').fill('30');
  await card.getByRole('button', { name: 'Исправить цифры' }).click();
  await expect(page.getByTestId('resolved')).toBeVisible();

  const restored = await request.get(`/api/v1/venues/${venue}/menu`);
  const fixed = ((await restored.json()) as { items: { id: number; nutrients: { kcal: number } }[] }).items.find(
    (entry) => entry.id === item.id,
  );
  expect(fixed?.nutrients.kcal).toBe(300);
});
