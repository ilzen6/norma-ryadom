import { expect, test } from '@playwright/test';
import {
  allText,
  button,
  openFlutterApp,
  openTab,
  semanticTexts,
  screenshot,
  scrollDown,
  text,
  typeInto,
} from './support/flutter';

test.describe.configure({ mode: 'serial' });

test('сценарий защиты: от нормы до записи обеда в дневник', async ({ page }) => {
  await openFlutterApp(page);

  await test.step('онбординг: параметры тела и расчёт нормы', async () => {
    await expect(text(page, 'Шаг 1 из 3')).toBeVisible();
    await typeInto(page, 'Возраст, лет', '25');
    await typeInto(page, 'Рост, см', '165');
    await typeInto(page, 'Вес, кг', '62');
    await page.getByRole('radio', { name: 'Умеренная: 3–5 тренировок' }).click();
    await button(page, 'Снижение веса').click();
    await scrollDown(page, 2);
    await expect(text(page, '1800 ккал')).toBeVisible();
    await expect(text(page, 'Белки 99 г · Жиры 56 г · Углеводы 225 г')).toBeVisible();
    await screenshot(page, 'app-01-norm');
    await button(page, 'Далее').click();
  });

  await test.step('онбординг: предпочтения и геолокация', async () => {
    await expect(text(page, 'Шаг 2 из 3')).toBeVisible();
    await page.getByRole('checkbox', { name: 'Без свинины' }).click();
    await screenshot(page, 'app-02-preferences');
    await button(page, 'Далее').click();
    await expect(text(page, 'Шаг 3 из 3')).toBeVisible();
    await button(page, 'Разрешить геолокацию').click();
    await expect(text(page, 'Геолокация разрешена')).toBeVisible();
    await screenshot(page, 'app-03-location');
    await button(page, 'Начать').click();
  });

  await test.step('главный экран: остаток на сегодня и цель обеда', async () => {
    await expect(text(page, 'Осталось на сегодня')).toBeVisible();
    await expect(text(page, '1800 ккал, белок 99 г')).toBeVisible();
    await button(page, 'Обед').click();
    await expect(text(page, /≈ 630 ккал ± 63/)).toBeVisible();
    await expect(text(page, 'Рядом с вами')).toBeVisible();
    await screenshot(page, 'app-04-home');
  });

  await test.step('подбор рядом: несколько вариантов в разных сетях', async () => {
    await button(page, 'Подобрать рядом').click();
    const options = page.locator('flt-semantics[role="button"]').filter({ hasText: /ккал · Б/ });
    await expect(options.first()).toBeVisible();
    expect(await options.count()).toBeGreaterThanOrEqual(3);
    await expect(allText(page, /свин|ветчин|рёбрышки|бужени|пепперони|карбонара/i)).toHaveCount(0);
    await screenshot(page, 'app-05-nearby-results');
    await options.first().click();
  });

  await test.step('результат подбора: отклонения по показателям и замена блюда', async () => {
    await expect(text(page, 'Попадание в цель')).toBeVisible();
    await expect(text(page, /Калории \d+ из \d+/)).toBeVisible();
    await expect(text(page, /Белок \d+ г, нужно от \d+ г/)).toBeVisible();
    await screenshot(page, 'app-06-combo');
    const before = await semanticTexts(page, /ккал · Б/);
    await page
      .getByRole('button', { name: /^Заменить «/ })
      .last()
      .click();
    await expect(text(page, 'Чем заменить')).toBeVisible();
    await screenshot(page, 'app-07-replacements');
    const replacement = page
      .locator('flt-semantics[role="button"]')
      .filter({ hasText: /ккал · Б/ })
      .last();
    await replacement.click();
    await expect(text(page, 'Чем заменить')).toBeHidden();
    const after = await semanticTexts(page, /ккал · Б/);
    expect(before.length).toBeGreaterThan(0);
    expect(after).not.toEqual(before);
    await screenshot(page, 'app-08-combo-replaced');
  });

  await test.step('«Записать в дневник»: дневник обновился, прогресс сдвинулся', async () => {
    await button(page, 'Записать в дневник').click();
    await expect(text(page, 'Записано в дневник')).toBeVisible();
    await expect(text(page, 'Съедено')).toBeVisible();
    await expect(text(page, /Калории, ккал: [1-9]\d* из 1800/)).toBeVisible();
    await screenshot(page, 'app-09-diary');
  });

  await test.step('главный экран показывает уменьшившийся остаток', async () => {
    await openTab(page, 'Что взять');
    await expect(text(page, /\d+ ккал, белок \d+ г/)).toBeVisible();
    await expect(text(page, '1800 ккал, белок 99 г')).toBeHidden();
  });

  await test.step('карта: цветные точки и список заведений', async () => {
    await openTab(page, 'Карта');
    await expect(text(page, 'есть набор под цель')).toBeVisible();
    const venues = page.locator('flt-semantics[role="button"]').filter({ hasText: / м$/ });
    await expect(venues.first()).toBeVisible();
    await screenshot(page, 'app-10-map');
    await venues.filter({ hasText: 'Гриль Хаус, Москва-Сити' }).click();
  });

  await test.step('экран заведения: значки достоверности и пометки', async () => {
    await expect(text(page, 'Меню')).toBeVisible();
    await expect(allText(page, /данные сети · проверено/).first()).toBeVisible();
    await expect(allText(page, 'подходит').first()).toBeVisible();
    await screenshot(page, 'app-11-venue-menu');
    await button(page, 'Собрать обед здесь').click();
    await expect(
      page
        .locator('flt-semantics[role="button"]')
        .filter({ hasText: /ккал · Б/ })
        .first(),
    ).toBeVisible();
    await screenshot(page, 'app-12-venue-combos');
  });

  await test.step('жалоба «цифры не совпадают»', async () => {
    await button(page, 'Цифры не совпадают').first().click();
    await typeInto(page, 'Например: на стенде 520 ккал', 'На стенде указано 420 ккал');
    await button(page, 'Отправить').click();
    await expect(text(page, 'Спасибо! Блюдо проверим')).toBeVisible();
  });

  await test.step('загрузка фото меню из галереи', async () => {
    await button(page, 'Сфотографировать меню').click();
    const chooser = page.waitForEvent('filechooser');
    await button(page, 'Из галереи').click();
    await (await chooser).setFiles('fixtures/menu-photo.png');
    await expect(text(page, 'Спасибо! Фото отправлено на проверку')).toBeVisible();
    await screenshot(page, 'app-13-photo-sent');
  });
});
