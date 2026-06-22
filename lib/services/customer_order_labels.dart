class CustomerOrderOption {
  final String title;
  final String? subtitle;

  const CustomerOrderOption({required this.title, this.subtitle});
}

class CustomerOrderLabels {
  const CustomerOrderLabels._();

  static const complexitySectionTitle = 'Что должно быть в проекте?';
  static const complexitySectionHint =
      'Отметьте нужные пункты — так исполнители быстрее поймут объём работы.';

  static const screensLabel = 'Сколько страниц или разделов';
  static const screensHint =
      'Например: главная, каталог и корзина — это 3 раздела';

  static const complexityPreviewTitle = 'Примерная сложность';
  static const complexityPreviewHint =
      'Система оценивает задачу по вашим ответам — исполнитель может уточнить оценку.';

  static CustomerOrderOption complexityFactor(String code) {
    switch (code) {
      case 'files':
        return const CustomerOrderOption(
          title: 'Загрузка файлов',
          subtitle: 'Фото, документы, вложения от пользователей',
        );
      case 'auth':
        return const CustomerOrderOption(
          title: 'Регистрация и вход',
          subtitle: 'Личный кабинет, профиль или разные типы пользователей',
        );
      case 'database':
        return const CustomerOrderOption(
          title: 'Хранение данных',
          subtitle: 'Товары, заказы, история — информация сохраняется на сервере',
        );
      case 'api':
        return const CustomerOrderOption(
          title: 'Связь с другими сервисами',
          subtitle: 'CRM, 1С, Telegram, почта, карты, сторонние сайты',
        );
      case 'payment':
        return const CustomerOrderOption(
          title: 'Оплата на сайте или в приложении',
          subtitle: 'Банковская карта, СБП, онлайн-касса',
        );
      default:
        return const CustomerOrderOption(title: 'Дополнительная функция');
    }
  }

  static String factorStoredLabel(String code) {
    return complexityFactor(code).title;
  }

  static String languageLabel(String technicalName) {
    switch (technicalName.trim()) {
      case 'JavaScript':
        return 'Сайты и веб-приложения';
      case 'Dart':
        return 'Мобильные приложения';
      case 'Python':
        return 'Серверы, боты и автоматизация';
      case 'TypeScript':
        return 'Современные сайты и сервисы';
      case 'Go':
        return 'Быстрые серверные системы';
      default:
        return technicalName;
    }
  }

  static String? languageHint(String technicalName) {
    switch (technicalName.trim()) {
      case 'JavaScript':
        return 'JavaScript — для обычных сайтов и интернет-магазинов';
      case 'Dart':
        return 'Dart — для приложений на телефон';
      case 'Python':
        return 'Python — для серверной части и скриптов';
      case 'TypeScript':
        return 'TypeScript — для сложных веб-проектов';
      case 'Go':
        return 'Go — для высоконагруженных серверов';
      default:
        return null;
    }
  }

  static String frameworkLabel(String technicalName) {
    switch (technicalName.trim()) {
      case 'Flutter':
        return 'Мобильное приложение (iOS и Android)';
      case 'React':
        return 'Сайт или интернет-магазин';
      case 'Vue':
        return 'Сайт с личным кабинетом';
      case 'Angular':
        return 'Крупный корпоративный сайт';
      case 'Next.js':
        return 'Быстрый современный сайт';
      case 'Nuxt':
        return 'Сайт с SEO и каталогом';
      case 'Express':
        return 'Сервер для сайта или приложения';
      case 'Svelte':
        return 'Лёгкий интерактивный сайт';
      case 'Django':
        return 'Админ-панель или сервер сайта';
      case 'FastAPI':
        return 'Серверная часть проекта';
      case 'Flask':
        return 'Небольшой сервер или сервис';
      case 'Serverpod':
        return 'Сервер для мобильного приложения';
      case 'Flame':
        return 'Мобильная или браузерная игра';
      case 'NestJS':
        return 'Сервер для бизнес-приложения';
      case 'Gin':
        return 'Высокоскоростной сервер';
      default:
        return technicalName;
    }
  }

  static String? frameworkHint(String technicalName) {
    final trimmed = technicalName.trim();
    if (trimmed.isEmpty) return null;

    return 'Технология для исполнителя: $trimmed';
  }

  static String pickerTitle(String technicalName, {required bool isFramework}) {
    final label =
        isFramework ? frameworkLabel(technicalName) : languageLabel(technicalName);

    if (label == technicalName) {
      return technicalName;
    }

    return '$label ($technicalName)';
  }

  static String rowValue(String technicalName, {required bool isFramework}) {
    if (technicalName == 'Не выбрано') {
      return technicalName;
    }

    return isFramework
        ? frameworkLabel(technicalName)
        : languageLabel(technicalName);
  }
}
