import { describe, expect, it } from 'vitest';
import { STRINGS, t } from './i18n';

describe('i18n', () => {
  it('returns English copy', () => {
    expect(t('settings.title', 'en')).toBe('Settings');
  });

  it('returns Russian copy', () => {
    expect(t('settings.title', 'ru')).toBe('Настройки');
  });

  it('every key exists in both languages', () => {
    const en = Object.keys(STRINGS.en);
    const ru = Object.keys(STRINGS.ru);
    expect(ru.sort()).toEqual(en.sort());
  });
});
