# Лабораторна робота №4 (IaC. Terraform. Ansible)

## Структура репозиторію
- `/lab1-3` - файли попередніх робіт (застосунок, Docker, тести тощо).
- `/lab4/terraform` - Автоматизація розгортання інфраструктури (Terraform, libvirt).
- `/lab4/ansible` - Управління конфігураціями (Ansible).

## Вимоги
- **ОС:** Linux (для роботи `libvirt` та Ansible).
- **ПЗ:** `terraform`, `ansible`, `qemu-kvm`, `libvirt-daemon-system`.
- **SSH:** Згенерований ключ у `~/.ssh/id_rsa.pub`.

## Крок 1. Розгортання інфраструктури (Terraform)
1. Перейдіть до директорії з Terraform конфігурацією:
   ```bash
   cd lab4/terraform
   ```
2. Ініціалізуйте провайдери та створіть ресурси:
   ```bash
   terraform init
   terraform apply -auto-approve
   ```
3. Після завершення роботи Terraform виведе дві IP-адреси (`worker_ip` та `db_ip`).

## Крок 2. Налаштування конфігурації (Ansible)
Ваш варіант `N = 9`. Для вас налаштовані порти `8009` для веб-додатку і `5441` для БД.

1. Перейдіть в папку `lab4/ansible/` і відредагуйте файл `inventory.ini`, замінивши `<WORKER_IP>` та `<DB_IP>` на отримані адреси з Terraform:
   ```ini
   [workers]
   worker ansible_host=192.168.122.X

   [db]
   database ansible_host=192.168.122.Y
   ```
2. Запустіть Ansible плейбук:
   ```bash
   ansible-playbook -i inventory.ini site.yml
   ```

Після виконання плейбука система буде повністю налаштована:
- **Nginx** слухає порт `80` і проксіює трафік на **Node.js** застосунок.
- Застосунок підключається до **PostgreSQL** на ноді `db`.
- Створені всі необхідні користувачі (`ansible`, `teacher`, `operator`, `app`, `student`), а користувач `operator` може виконувати обмежені команди sudo для керування сервісами.
