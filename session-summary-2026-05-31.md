# Підсумковий звіт сесії аудиту безпеки Windows

**Дата:** 2026-05-31
**Система:** Windows 11 Pro (DESKTOP-SHC8F13)
**Виконав:** Yevhen Volovyk
**Процесор:** Intel Core i5-14400F
**RAM:** 31.8 GB | **Диск C:** 930.5 GB (23% використано)

---

## Загальна оцінка

| Категорія              | До аудиту     | Після аудиту   |
|------------------------|---------------|----------------|
| Брандмауер             | Увімкнено     | Увімкнено + 4 нових правила |
| Відкриті порти назовні | 3 (135, 7680, 27036) | 1 (135 — стандартний RPC) |
| UAC                    | Рівень 2      | Рівень 5 (максимум) |
| Телеметрія DiagTrack   | Running       | Stopped / Disabled |
| Автозапуск             | 3 записи      | 1 запис (OpenVPN) |
| Заплановані задачі     | 7 активних    | 2 активних |

---

## 1. Брандмауер — додані правила

| Правило | Протокол | Порт | Напрямок |
|---------|----------|------|----------|
| Block Steam Remote Play | TCP | 27036 | Inbound |
| Block Steam Remote Play | UDP | 27036 | Inbound |
| Block Steam mDNS | UDP | 5353 | Inbound |
| Block Windows Delivery Optimization | TCP | 7680 | Inbound |

**Стан усіх профілів брандмауера:** Domain / Private / Public — увімкнено, вхідний трафік заблоковано за замовчуванням, логування активне.

---

## 2. Відкриті порти — фінальний стан

| Порт | Процес | Доступність |
|------|--------|-------------|
| 135 TCP | svchost (RPC) | Доступний — стандартний Windows |
| 5040 TCP | svchost | Лише локально |
| 7680 TCP | svchost | Заблоковано брандмауером |
| 27036 TCP/UDP | steam | Заблоковано брандмауером |
| 5353 UDP | steamwebhelper | Заблоковано брандмауером |
| 27060, 50881, 50882 TCP | steam | Лише локально (127.0.0.1) |
| 49664–49669 TCP | Windows RPC | Динамічні, стандартні |
| 49668 TCP | jhi_service | Лише локально (::1) |

---

## 3. UAC — підвищення рівня

| Параметр | Було | Стало |
|----------|------|-------|
| ConsentPromptBehaviorAdmin | 2 | **5** |
| Поведінка | Запитувати при змінах програмами | **Завжди запитувати** |

Реєстр: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`

---

## 4. Телеметрія — вимкнено

| Дія | Результат |
|-----|-----------|
| Служба DiagTrack | **Stopped / Disabled** |
| AllowTelemetry (реєстр) | **0** (вимкнено) |

Реєстр: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection`

---

## 5. Автозапуск — очищення

### Видалено з реєстру (HKCU Run)
| Запис | Що робив |
|-------|----------|
| Steam | Запускав Steam у фоні при вході |
| OneDriveSetup | Незавершене перше налаштування OneDrive |

### Вимкнено заплановані задачі
| Задача | Категорія |
|--------|-----------|
| MicrosoftEdgeUpdateTaskMachineUA | Автооновлення Edge |
| MicrosoftEdgeUpdateTaskMachineCore | Автооновлення Edge |
| RunPlatformExperienceHelper_Metrics | Google Chrome метрики |
| RunPlatformExperienceHelper_Daily | Google Chrome метрики |
| RunPlatformExperienceHelperOnUnlock | Google Chrome метрики |

### Залишено в автозапуску
| Запис | Причина |
|-------|---------|
| SecurityHealth (HKLM) | Windows Defender — обов'язковий |
| org.openvpn.client (HKCU) | OpenVPN — за бажанням користувача |
| npcapwatchdog (задача) | Npcap — для мережевих інструментів |
| GoogleUpdaterTask (задача) | Оновлення Chrome |

---

## 6. Стан захисту — фінальна перевірка

| Компонент | Стан |
|-----------|------|
| Windows Defender | Увімкнено |
| Захист у реальному часі | Увімкнено |
| Tamper Protection | Увімкнено |
| Версія сигнатур | 1.451.195.0 (оновлено 31.05.2026) |
| Controlled Folder Access | Увімкнено |
| UAC | Рівень 5 (максимум) |
| DiagTrack | Вимкнено |
| Брандмауер (всі профілі) | Увімкнено |

---

## 7. Облікові записи

| Обліковий запис | Статус |
|-----------------|--------|
| User | Активний |
| Administrator | Вимкнено |
| Guest | Вимкнено |
| DefaultAccount | Вимкнено |
| WDAGUtilityAccount | Вимкнено |

---

## 8. Команди для скасування всіх змін

```powershell
# Брандмауер — видалити правила
Remove-NetFirewallRule -DisplayName "Block Steam Remote Play (port 27036)"
Remove-NetFirewallRule -DisplayName "Block Steam Remote Play UDP (port 27036)"
Remove-NetFirewallRule -DisplayName "Block Steam mDNS UDP (port 5353)"
Remove-NetFirewallRule -DisplayName "Block Windows Delivery Optimization (port 7680)"

# UAC — повернути рівень 2
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name ConsentPromptBehaviorAdmin -Value 2

# DiagTrack — увімкнути
Set-Service -Name DiagTrack -StartupType Automatic; Start-Service -Name DiagTrack
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name AllowTelemetry -Value 1

# Автозапуск — відновити Steam
Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "Steam" -Value '"C:\Program Files (x86)\Steam\steam.exe" -silent'

# Задачі — увімкнути Edge update
Get-ScheduledTask | Where-Object {$_.TaskName -like "MicrosoftEdgeUpdate*"} | Enable-ScheduledTask
```

---

## 9. Рекомендації на майбутнє

1. **Мережевий профіль** — змінити з Public на Private для домашньої мережі.
2. **Оновлення Windows** — останнє оновлення безпеки від 19.05.2026. Рекомендовано перевіряти щотижня.
3. **Steam** — розглянути вимкнення дозвільних правил Steam у брандмауері, якщо онлайн-гри не використовуються.
4. **Intel JHI Service** — слухає на ::1, нешкідливо, але можна вимкнути якщо Intel ME не потрібен.
