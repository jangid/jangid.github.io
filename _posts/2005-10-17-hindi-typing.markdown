---
layout: post
title:  "Hindi typing"
date:   2005-10-17 16:50:00
tags: hindi
---

To configure your linux box for hindi typing is very easy. Just do these settings in you /etc/X11/xorg.conf file under "InputDevice" section and restart your xserver,

Option "XkbRules" "xorg"\\
Option "XkbModel" "pc104"\\
Option "XkbLayout" "en_US,dev"\\
Option "XkbOptions" "grp:alt_shift_toggle,grp_led:scroll"

These settings will allow you to change your keyboard layout using alt+shift key combination. 

**References**:

1. [http://www.linuxquestions.org/questions/showthread.php?postid=1126215](http://www.linuxquestions.org/questions/showthread.php?postid=1126215)
2. [http://www.livejournal.com/users/bassanti/361.html?thread=14697#t14697](http://www.livejournal.com/users/bassanti/361.html?thread=14697#t14697)
3. [http://www.balendu.com/madhyam/keyboards.htm](http://www.balendu.com/madhyam/keyboards.htm) (for inscript keyboard layout see)

Windows users see windows documentation for changing keyboard layout but the keyboard layout for hindi (inscript) remains same as above 3rd link.

I have translated the [bassanti](http://bassanti.livejournal.com/)'s entry check [here](http://www.livejournal.com/users/bassanti/361.html?thread=13929#t13929).

तो हो जाओ शुरू।
