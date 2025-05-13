# Ubuntu GNOME Audio Utilities

A collection of shell scripts to help manage audio settings on Ubuntu systems running the GNOME desktop environment. These scripts are particularly useful for disabling the "Auto-Mute Mode" and for quickly switching between audio output ports like Line Out and Headphones when they are on the same audio device.

**Tested primarily on Ubuntu 25.04 with GNOME Desktop.**

## Scripts Overview

This repository contains the following scripts:

1.  **`Set_Auto-Mute_Mode_Disabled.sh`**:
    *   Disables the 'Auto-Mute Mode' in ALSA mixer settings. This can be helpful if your system automatically mutes speakers when headphones are plugged in (or vice-versa) and you prefer manual control or a different behavior.

2.  **`Change_Audio_Output_Port.sh`**:
    *   Allows you to switch (toggle) between two predefined audio output ports on your primary sound card (e.g., between 'Line Out' and 'Headphones').
    *   This script is intended to be run directly or via the shortcut set up by `Audio_Change_Setup.sh`.

3.  **`Audio_Change_Setup.sh`**:
    *   An installation script that:
        *   Moves the `Change_Audio_Output_Port.sh` script to `/bin/` (making it accessible system-wide by just typing `Change_Audio_Output_Port`).
        *   Attempts to set up a global keyboard shortcut (default: **F12**) to run `Change_Audio_Output_Port.sh` for quick audio output switching.

## Important Limitation: Sink vs. Ports

These scripts, especially `Change_Audio_Output_Port.sh`, are designed for systems where your different audio outputs (e.g., front panel headphones and rear panel line-out jacks) are treated as different **ports** on the **same audio sink/sound card** by PulseAudio/PipeWire.

They are generally **not** designed to switch between entirely separate sound cards (e.g., onboard audio vs. a USB DAC), which are usually represented as different sinks.

## Requirements

*   **Operating System**: Ubuntu (tested on 25.04)
*   **Desktop Environment**: GNOME (the shortcut setup in `Audio_Change_Setup.sh` uses `gsettings`, which is specific to GNOME).
*   **Required Packages**:
    *   `pactl` (usually part of `pulseaudio-utils` or `pipewire-pulse`)
    *   `amixer` (usually part of `alsa-utils`)
    *   `awk` (standard on most Linux systems)
    *   `notify-send` (for desktop notifications, optional for core functionality but used in `Change_Audio_Output_Port.sh`)

## Installation & Usage

### General

1.  Clone this repository or download the scripts.
2.  Make the scripts executable:
    ```bash
    chmod +x Set_Auto-Mute_Mode_Disabled.sh
    chmod +x Change_Audio_Output_Port.sh
    chmod +x Audio_Change_Setup.sh
    ```

### 1. `Set_Auto-Mute_Mode_Disabled.sh`

*   This script attempts to find your default sound card and disable 'Auto-Mute Mode'.
*   **Usage**: Run it directly from your terminal. It usually does not require `sudo`.
    ```bash
    ./Set_Auto-Mute_Mode_Disabled.sh
    ```
*   If you encounter errors like "Host is down", ensure your sound server (PulseAudio/PipeWire) is running correctly. This script should be run as your regular user.

### 2. `Change_Audio_Output_Port.sh` (Standalone Usage)

*   Before using the setup script, or if you prefer not to install it system-wide, you can run this script directly.
*   **Configuration**: You may need to edit `Change_Audio_Output_Port.sh` to set the correct `PORT1_NAME` and `PORT2_NAME` variables to match the port names on your system (as shown by `pactl list sinks`).
*   **Usage**: Run it directly. Does not require `sudo`.
    ```bash
    ./Change_Audio_Output_Port.sh
    ```

### 3. `Audio_Change_Setup.sh` (For `Change_Audio_Output_Port.sh`)

*   This script automates the installation and shortcut setup for `Change_Audio_Output_Port.sh`.
*   **Prerequisites**:
    *   Ensure `Change_Audio_Output_Port.sh` is in the **same directory** as `Audio_Change_Setup.sh` when you run the setup.
    *   You have configured the port names inside `Change_Audio_Output_Port.sh` if necessary.
*   **Usage**: This script **must be run with `sudo`** because it moves a file to `/bin/` and modifies system/user settings for keyboard shortcuts.
    ```bash
    sudo ./Audio_Change_Setup.sh
    ```
*   **Post-Setup**:
    *   You should be able to run `Change_Audio_Output_Port` from any terminal.
    *   Pressing **F12** should execute the `Change_Audio_Output_Port` script. You might need to log out and log back in, or restart GNOME Shell (Alt+F2, type `r`, Enter - on X11) for the shortcut to become active.

## Troubleshooting

*   **`pactl` or `amixer` errors**: Ensure the relevant packages are installed and your sound server is running.
*   **"Connection refused" or "Host is down" for `pactl`**: You are likely running a script that uses `pactl` with `sudo` when it should be run as a regular user, or your sound server is not running for your user session. `Audio_Change_Setup.sh` needs `sudo`, but the other two generally do not.
*   **Shortcut not working**:
    *   Ensure you are on GNOME.
    *   Try logging out and back in.
    *   Check GNOME Keyboard settings for conflicting shortcuts or if the custom shortcut was created successfully.
*   **Port switching not working**:
    *   Verify the port names configured in `Change_Audio_Output_Port.sh` (`PORT1_NAME`, `PORT2_NAME`) exactly match the output of `pactl list sinks` for your target device.
    *   Confirm your audio devices are on the same sink, just different ports (see "Important Limitation" above).

---

# أدوات مساعدة للصوت في Ubuntu GNOME

مجموعة من السكربتات (البرامج النصية) للمساعدة في إدارة إعدادات الصوت على أنظمة Ubuntu التي تستخدم بيئة سطح مكتب GNOME. هذه السكربتات مفيدة بشكل خاص لتعطيل وضع "الكتم التلقائي" (Auto-Mute Mode) وللتبديل السريع بين منافذ إخراج الصوت مثل مخرج الخط (Line Out) وسماعات الرأس (Headphones) عندما تكون هذه المنافذ على نفس جهاز الصوت.

**تم الاختبار بشكل أساسي على Ubuntu 25.04 مع سطح مكتب GNOME.**

## نظرة عامة على السكربتات

يحتوي هذا المستودع على السكربتات التالية:

1.  **`Set_Auto-Mute_Mode_Disabled.sh`**:
    *   يقوم بتعطيل وضع "الكتم التلقائي" (Auto-Mute Mode) في إعدادات خلاط الصوت ALSA. يمكن أن يكون هذا مفيدًا إذا كان نظامك يقوم بكتم صوت السماعات الخارجية تلقائيًا عند توصيل سماعات الرأس (أو العكس) وكنت تفضل التحكم اليدوي أو سلوكًا مختلفًا.

2.  **`Change_Audio_Output_Port.sh`**:
    *   يسمح لك بالتبديل (التنقل) بين منفذي إخراج صوت محددين مسبقًا على بطاقة الصوت الأساسية لديك (على سبيل المثال، بين 'Line Out' و 'Headphones').
    *   تم تصميم هذا السكربت ليتم تشغيله مباشرة أو عبر الاختصار الذي يتم إعداده بواسطة `Audio_Change_Setup.sh`.

3.  **`Audio_Change_Setup.sh`**:
    *   سكربت تثبيت يقوم بما يلي:
        *   ينقل سكربت `Change_Audio_Output_Port.sh` إلى `/bin/` (مما يجعله قابلاً للوصول من أي مكان في النظام بمجرد كتابة `Change_Audio_Output_Port`).
        *   يحاول إعداد اختصار لوحة مفاتيح عام (الافتراضي: **F12**) لتشغيل سكربت `Change_Audio_Output_Port.sh` للتبديل السريع لمخرج الصوت.

## قيد هام: الفرق بين جهاز الصوت (Sink) والمنفذ (Port)

هذه السكربتات، وخاصة `Change_Audio_Output_Port.sh`، مصممة للأنظمة التي يتم فيها التعامل مع مخارج الصوت المختلفة لديك (مثل مقبس سماعات الرأس في اللوحة الأمامية ومقبس مخرج الخط في اللوحة الخلفية) على أنها **منافذ (ports)** مختلفة تنتمي إلى **نفس جهاز الصوت (sink) / بطاقة الصوت** بواسطة PulseAudio/PipeWire.

بشكل عام، هي **ليست** مصممة للتبديل بين بطاقات صوت منفصلة تمامًا (مثل الصوت المدمج في اللوحة الأم مقابل بطاقة صوت USB)، والتي عادةً ما يتم تمثيلها كـ sinks مختلفة.

## المتطلبات

*   **نظام التشغيل**: Ubuntu (تم الاختبار على 25.04)
*   **بيئة سطح المكتب**: GNOME (إعداد الاختصار في `Audio_Change_Setup.sh` يستخدم `gsettings` الخاص بـ GNOME).
*   **الحزم المطلوبة**:
    *   `pactl` (عادةً جزء من `pulseaudio-utils` أو `pipewire-pulse`)
    *   `amixer` (عادةً جزء من `alsa-utils`)
    *   `awk` (قياسي في معظم أنظمة Linux)
    *   `notify-send` (للإشعارات على سطح المكتب، اختياري للوظائف الأساسية ولكنه مستخدم في `Change_Audio_Output_Port.sh`)

## التثبيت والاستخدام

### عام

1.  انسخ هذا المستودع (clone) أو قم بتنزيل السكربتات.
2.  اجعل السكربتات قابلة للتنفيذ:
    ```bash
    chmod +x Set_Auto-Mute_Mode_Disabled.sh
    chmod +x Change_Audio_Output_Port.sh
    chmod +x Audio_Change_Setup.sh
    ```

### 1. `Set_Auto-Mute_Mode_Disabled.sh`

*   يحاول هذا السكربت العثور على بطاقة الصوت الافتراضية لديك وتعطيل وضع 'Auto-Mute Mode'.
*   **الاستخدام**: قم بتشغيله مباشرة من الطرفية (terminal). لا يتطلب عادةً صلاحيات `sudo`.
    ```bash
    ./Set_Auto-Mute_Mode_Disabled.sh
    ```
*   إذا واجهت أخطاء مثل "Host is down"، تأكد من أن خادم الصوت لديك (PulseAudio/PipeWire) يعمل بشكل صحيح. يجب تشغيل هذا السكربت كمستخدم عادي.

### 2. `Change_Audio_Output_Port.sh` (استخدام مستقل)

*   قبل استخدام سكربت الإعداد، أو إذا كنت تفضل عدم تثبيته على مستوى النظام، يمكنك تشغيل هذا السكربت مباشرة.
*   **الإعداد**: قد تحتاج إلى تحرير ملف `Change_Audio_Output_Port.sh` لتعيين متغيرات `PORT1_NAME` و `PORT2_NAME` الصحيحة لتتوافق مع أسماء المنافذ في نظامك (كما تظهر في ناتج الأمر `pactl list sinks`).
*   **الاستخدام**: قم بتشغيله مباشرة. لا يتطلب صلاحيات `sudo`.
    ```bash
    ./Change_Audio_Output_Port.sh
    ```

### 3. `Audio_Change_Setup.sh` (لـ `Change_Audio_Output_Port.sh`)

*   يقوم هذا السكربت بأتمتة عملية التثبيت وإعداد الاختصار لسكربت `Change_Audio_Output_Port.sh`.
*   **المتطلبات المسبقة**:
    *   تأكد من أن `Change_Audio_Output_Port.sh` موجود في **نفس المجلد** مع `Audio_Change_Setup.sh` عند تشغيل سكربت الإعداد.
    *   قد قمت بتكوين أسماء المنافذ داخل `Change_Audio_Output_Port.sh` إذا لزم الأمر.
*   **الاستخدام**: يجب تشغيل هذا السكربت **باستخدام `sudo`** لأنه ينقل ملفًا إلى `/bin/` ويعدل إعدادات النظام/المستخدم لاختصارات لوحة المفاتيح.
    ```bash
    sudo ./Audio_Change_Setup.sh
    ```
*   **بعد الإعداد**:
    *   يجب أن تكون قادرًا على تشغيل `Change_Audio_Output_Port` من أي طرفية.
    *   الضغط على **F12** يجب أن ينفذ سكربت `Change_Audio_Output_Port`. قد تحتاج إلى تسجيل الخروج ثم الدخول مرة أخرى، أو إعادة تشغيل GNOME Shell (Alt+F2، اكتب `r`، Enter - على X11) حتى يصبح الاختصار فعالاً.

## استكشاف الأخطاء وإصلاحها

*   **أخطاء `pactl` أو `amixer`**: تأكد من تثبيت الحزم ذات الصلة وأن خادم الصوت لديك قيد التشغيل.
*   **"Connection refused" أو "Host is down" لـ `pactl`**: من المحتمل أنك تقوم بتشغيل سكربت يستخدم `pactl` باستخدام `sudo` بينما يجب تشغيله كمستخدم عادي، أو أن خادم الصوت لا يعمل لجلسة المستخدم الخاصة بك. يحتاج `Audio_Change_Setup.sh` إلى `sudo`، لكن السكربتين الآخرين لا يحتاجان إليه عادةً.
*   **الاختصار لا يعمل**:
    *   تأكد من أنك تستخدم GNOME.
    *   حاول تسجيل الخروج والدخول مرة أخرى.
    *   تحقق من إعدادات لوحة المفاتيح في GNOME بحثًا عن اختصارات متعارضة أو إذا تم إنشاء الاختصار المخصص بنجاح.
*   **تبديل المنفذ لا يعمل**:
    *   تحقق من أن أسماء المنافذ التي تم تكوينها في `Change_Audio_Output_Port.sh` (`PORT1_NAME`, `PORT2_NAME`) تتطابق تمامًا مع ناتج `pactl list sinks` لجهازك المستهدف.
    *   تأكد من أن أجهزة الصوت لديك موجودة على نفس الـ sink، ولكن فقط منافذ مختلفة (انظر "قيد هام" أعلاه).

---

لا تتردد في تعديل ملف README هذا ليناسب بشكل أفضل أي تفاصيل إضافية أو تغييرات تقوم بها!
