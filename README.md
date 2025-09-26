# OSCam_r11720_emu_smod - autoinstall

Automatska instalacija i konfiguracija OSCam-a sa podrškom za EMU i SMOD.

## Kako koristiti

1. Dodaj svoju provjerenu binarku u `bin/oscam2`
2. Stavi svoje konfiguracije u `configs/` (oscam.conf, oscam.user, oscam.services...)
3. (Opcionalno) stavi patcheve u `patches/`
4. Pokreni:
   ```bash
   sudo ./install.sh --with-ffdecsa --with-patch-apply
   ```

## Opcije instalacije

- `--with-ffdecsa` : Instalira FFDecsa podršku
- `--with-patch-apply` : Primjenjuje patcheve iz patches/ direktorija
- `--no-systemd` : Preskače instalaciju systemd servisa

## Provjera statusa

```bash
# Status servisa
sudo systemctl status oscam2

# Zadnjih 200 linija loga
sudo tail -n 200 /usr/local/etc/oscam2/oscam.log
```

## Dodavanje opcija servisu

Možete dodati opcije bez editovanja service fajla:

```bash
# Edituj override
sudo systemctl edit oscam2.service

# Dodaj:
[Service]
Environment="OPTIONS=-b -r 2"

# Primjeni promjene
sudo systemctl daemon-reload
sudo systemctl restart oscam2
```

## Struktura repozitorija

```
OSCam_r11720_emu_smod/
├── bin/
│   └── oscam2               # (ovdje dodaj svoju provjerenu binarku)
├── configs/
│   ├── oscam.conf
│   ├── oscam.user
│   ├── oscam.services
│   └── other-configs...
├── patches/
│   ├── ffdecsa.patch
│   ├── icam.patch
│   └── ecm_opt.patch
├── service/
│   └── oscam2.service
├── install.sh
└── README.md
```

## Napomena

Ovaj repo služi za legalnu administraciju TV headend / smartcard čitača i debugging. Ne koristite za ilegalne radnje.