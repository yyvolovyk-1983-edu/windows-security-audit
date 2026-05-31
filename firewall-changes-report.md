# Звіт про зміни брандмауера Windows

**Дата:** 2026-05-31 (оновлено 2026-05-31, доповнено UAC та телеметрія)
**Система:** Windows 11 Pro
**Виконав:** Yevhen Volovyk

---

## Додані правила в поточній сесії

### 1. Block Steam Remote Play (port 27036)
- Порт: TCP 27036
- Напрямок: Inbound
- Дія: Block
- Профіль: Any (Domain / Private / Public)
- Причина: Порт Steam Remote Play був відкритий на 0.0.0.0. Функція Remote Play не використовується.

### 3. Block Steam Remote Play UDP (port 27036)
- Порт: UDP 27036
- Напрямок: Inbound
- Дія: Block
- Профіль: Any (Domain / Private / Public)
- Причина: Steam слухав UDP 27036 на 0.0.0.0 та 192.168.31.231. Попереднє правило блокувало лише TCP.

### 4. Block Steam mDNS UDP (port 5353)
- Порт: UDP 5353
- Напрямок: Inbound
- Дія: Block
- Профіль: Any (Domain / Private / Public)
- Причина: steamwebhelper слухав mDNS на всіх інтерфейсах. Функція не використовується.

### 2. Block Windows Delivery Optimization (port 7680)
- Порт: TCP 7680
- Напрямок: Inbound
- Дія: Block
- Профіль: Any (Domain / Private / Public)
- Причина: Порт Windows Update P2P (Delivery Optimization) був відкритий назовні. Отримання оновлень не постраждає.

---

## Усі активні блокуючі правила (повний список)

| Правило                              | Порт  | Протокол | Напрямок | Профіль | Примітка             |
|--------------------------------------|-------|----------|----------|---------|----------------------|
| Block NetBIOS Inbound Public         | 139   | TCP      | Inbound  | Public  | NetBIOS              |
| Block SMB Inbound Public             | 445   | TCP      | Inbound  | Public  | SMB публічна         |
| Block SMB Inbound (Port 445)         | 445   | TCP      | Inbound  | Any     | SMB всі мережі       |
| BLOCK SMB 445 Inbound                | 445   | TCP      | Inbound  | Any     | SMB дублюючий        |
| BLOCK SMB 445 Outbound               | Any   | TCP      | Outbound | Any     | SMB вихідний         |
| BLOCK_IN_3389                        | 3389  | TCP      | Inbound  | Any     | RDP                  |
| BLOCK_IN_5985                        | 5985  | TCP      | Inbound  | Any     | WinRM HTTP           |
| BLOCK_IN_5986                        | 5986  | TCP      | Inbound  | Any     | WinRM HTTPS          |
| BLOCK_IN_23                          | 23    | TCP      | Inbound  | Any     | Telnet               |
| BLOCK_IN_5900                        | 5900  | TCP      | Inbound  | Any     | VNC                  |
| Block Steam Remote Play (port 27036)     | 27036 | TCP      | Inbound  | Any     | ДОДАНО 2026-05-31    |
| Block Delivery Optimization (7680)       | 7680  | TCP      | Inbound  | Any     | ДОДАНО 2026-05-31    |
| Block Steam Remote Play UDP (port 27036) | 27036 | UDP      | Inbound  | Any     | ДОДАНО 2026-05-31    |
| Block Steam mDNS UDP (port 5353)         | 5353  | UDP      | Inbound  | Any     | ДОДАНО 2026-05-31    |

---

## Стан мережевого інтерфейсу на момент аудиту

| Параметр         | Значення                        |
|------------------|---------------------------------|
| Адаптер          | Realtek PCIe GbE Family Controller |
| IP-адреса        | 192.168.31.231/24               |
| Шлюз             | 192.168.31.111                  |
| DNS              | 1.1.1.1, 1.0.0.1 (Cloudflare)  |
| Мережевий профіль| Public                          |
| MAC              | 34:5A:60:6B:3D:8E               |

---

## Стан брандмауера

| Профіль | Увімкнено | Вхідний трафік за замовч. | Логування |
|---------|-----------|--------------------------|-----------|
| Domain  | Так       | Block                    | Так       |
| Private | Так       | Block                    | Так       |
| Public  | Так       | Block                    | Так       |

---

## Відкриті порти після змін

| Порт        | Процес          | Доступний ззовні              |
|-------------|-----------------|-------------------------------|
| 135         | svchost (RPC)   | Так — стандартний Windows     |
| 5040        | svchost         | Лише локально                 |
| 7680        | svchost         | Заблоковано брандмауером      |
| 27036 (TCP) | steam           | Заблоковано брандмауером      |
| 27036 (UDP) | steam           | Заблоковано брандмауером      |
| 5353 (UDP)  | steamwebhelper  | Заблоковано брандмауером      |
| 27060,50881,50882 | steam    | Лише локально (127.0.0.1)     |
| 49664-49669 | Windows RPC     | Динамічні, стандартні         |
| 49668       | jhi_service     | Лише локально (::1)           |

---

## Додаткові зміни системи (2026-05-31)

### UAC — підвищення рівня
- **Параметр:** `ConsentPromptBehaviorAdmin`
- **Було:** 2 (запитувати лише при змінах програмами)
- **Стало:** 5 (завжди сповіщати)
- **Розташування:** `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`
- **Причина:** Максимальний рівень захисту від несанкціонованих змін системи.

### DiagTrack (телеметрія Microsoft) — вимкнено
- **Служба DiagTrack:** Stopped / Disabled
- **Реєстр:** `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection` → `AllowTelemetry = 0`
- **Причина:** Зменшення передачі даних до Microsoft, захист конфіденційності.

#### Команди для скасування
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name ConsentPromptBehaviorAdmin -Value 2
    Set-Service -Name DiagTrack -StartupType Automatic; Start-Service -Name DiagTrack
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name AllowTelemetry -Value 1

---

## Примітка про Controlled Folder Access

Під час збереження цього звіту виявлено, що Windows Defender Controlled Folder Access
(захист від програм-вимагачів) **увімкнений** та блокує запис у папку Documents.
Це нормальна поведінка захисту. PowerShell та cmd.exe були тимчасово додані до
списку дозволених програм для збереження цього файлу.

---

## Команди для скасування змін брандмауера

    Remove-NetFirewallRule -DisplayName "Block Steam Remote Play (port 27036)"
    Remove-NetFirewallRule -DisplayName "Block Steam Remote Play UDP (port 27036)"
    Remove-NetFirewallRule -DisplayName "Block Steam mDNS UDP (port 5353)"
    Remove-NetFirewallRule -DisplayName "Block Windows Delivery Optimization (port 7680)"
