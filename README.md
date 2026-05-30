<div align="center">

# Windows Security Audit & Hardening

**PowerShell-скрипт комплексного аудиту та захисту Windows 11**

[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://github.com/yyvolovyk-1983-edu/windows-security-audit)
[![Platform](https://img.shields.io/badge/Windows_11-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/yyvolovyk-1983-edu/windows-security-audit)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Admin](https://img.shields.io/badge/Requires-Administrator-red?style=for-the-badge)]()

</div>

---

## Що робить скрипт

`harden_windows.ps1` — автоматизований аудит та захист Windows 11 Pro.
Перевіряє 12 категорій ризиків, усуває вразливості та генерує звіт з підсумками.

---

## Що перевіряє та виправляє

| # | Категорія | Дія |
|---|---|---|
| 1 | Облікові записи без пароля | Блокує мережевий вхід через реєстр |
| 2 | Guest / DefaultAccount | Вимикає невикористовувані системні акаунти |
| 3 | Політика блокування | 5 спроб → блокування на 30 хвилин |
| 4 | Автологін | Видаляє збережені облікові дані автовходу |
| 5 | SMBv1 / SMBv2 | Повністю вимикає застарілі протоколи |
| 6 | NetBIOS over TCP/IP | Вимикає на всіх мережевих інтерфейсах |
| 7 | Небезпечні порти | Firewall-правила для 9 портів (RDP, WinRM, Telnet, VNC, NetBIOS) |
| 8 | Віддалені служби | Зупиняє TermService, WinRM, RemoteRegistry, Remote Assistance |
| 9 | PowerShell v2 | Видаляє застарілий компонент (вектор обходу логування) |
| 10 | ScriptBlock Logging | Вмикає детальне логування PowerShell для форензіки |
| 11 | Audit Policies | Активує аудит облікових записів, входів, процесів |
| 12 | Windows Defender | Запускає повне сканування у фоні |

---

## Вимоги

- Windows 11 Pro (протестовано на Build 26200)
- PowerShell 5.1+
- **Права адміністратора** (обов'язково)

---

## Використання

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\harden_windows.ps1
```

---

## Приклад виводу

```
==============================
 Windows Security Hardening
==============================

[ACCOUNTS]
  [OK]   Мережевий вхід без пароля — заблоковано
  [OK]   Guest account — вимкнено

[NETWORK]
  [OK]   SMBv1 — вимкнено
  [OK]   SMBv2 — вимкнено
  [OK]   NetBIOS — вимкнено на 2 інтерфейсах

[FIREWALL]
  [OK]   Заблоковано порти: 445, 3389, 5985, 23, 5900, 137-139

[LOGGING]
  [OK]   ScriptBlock Logging — увімкнено
  [OK]   Audit Policies — налаштовано

==============================
 Результат: 14 OK | 2 WARN | 0 FAIL
==============================
```

---

## Виявлені вразливості (реальний кейс)

| Критичність | Вразливість |
|---|---|
| 🔴 Critical | Обліковий запис без пароля з мережевим доступом |
| 🔴 Critical | SMBv1 активовано (вектор WannaCry/EternalBlue) |
| 🟠 High | WinRM активний — віддалене виконання команд |
| 🟠 High | RemoteRegistry — зовнішній доступ до реєстру |
| 🟡 Medium | NetBIOS активний — витік імен в мережі |
| 🟡 Medium | PowerShell v2 встановлено (обхід логування) |
| 🟡 Medium | Відсутня політика блокування облікових записів |

**Всі вразливості усунені скриптом автоматично.**

---

## Структура репозиторію

```
windows-security-audit/
└── scripts/
    └── harden_windows.ps1
```

---

> **Увага:** Запускайте скрипт лише на системах, де маєте **письмовий дозвіл** або є власником.

---

<div align="center">

**Автор:** [Євген Воловик](https://github.com/yyvolovyk-1983-edu) · Харків, Україна
📧 y.y.volovyk@student.khai.edu · [LinkedIn](https://www.linkedin.com/in/yevhen-volovyk/)

</div>