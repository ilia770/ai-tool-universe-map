import type { Language } from './toolStoreContext';

/** Copy for the P6 surfaces only (account/settings/delete/language/about). */
export const STRINGS = {
  en: {
    'account.open': 'Account & settings',
    'settings.title': 'Settings',
    'settings.visualization': 'Visualization',
    'settings.language': 'Language',
    'settings.data': 'Data',
    'settings.about': 'About',
    'settings.export': 'Export my universe',
    'settings.reset': 'Reset everything',
    'settings.reset.confirm': 'Delete your added tools and settings?',
    'settings.close': 'Close',
    'about.body': 'A premium map of the AI-tool universe.',
    'tool.remove': 'Remove from my universe',
  },
  ru: {
    'account.open': 'Аккаунт и настройки',
    'settings.title': 'Настройки',
    'settings.visualization': 'Визуализация',
    'settings.language': 'Язык',
    'settings.data': 'Данные',
    'settings.about': 'О приложении',
    'settings.export': 'Экспорт моей вселенной',
    'settings.reset': 'Сбросить всё',
    'settings.reset.confirm': 'Удалить добавленные инструменты и настройки?',
    'settings.close': 'Закрыть',
    'about.body': 'Премиальная карта вселенной AI-инструментов.',
    'tool.remove': 'Убрать из моей вселенной',
  },
} as const;

export type StringKey = keyof (typeof STRINGS)['en'];

export function t(key: StringKey, lang: Language): string {
  return STRINGS[lang][key] ?? STRINGS.en[key];
}
