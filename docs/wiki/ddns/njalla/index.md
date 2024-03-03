---
title: DDNS Using Njalla
---

Go to your domain on njalla:

![Njalla Domain](/docs/wiki/ddns/njalla/domain.png)

Then press "Add record" and select "Dynamic" and write your subdomain in
the input box. It should now be added to your records. Click on the record,
you should now see something like the following:

![Njalla Record](/docs/wiki/ddns/njalla/record.png)

With this, then your JSON file should contain:

```json
  {
    "jellyfin.example.com": "48esqclnvqGiCZPbd"
  }
```

Add this as a secret file to your secrets (See [this page](/wiki/secrets)
for secrets management). This could be done, for example, in the following way:

- Writing the specified JSON to `/data/.secret/njalla/keys-file.json`
- Setting the owner as root: 
  - `sudo chown root:root /data/.secret/njalla/keys-file.json`
- Setting the permissions to 700 (read, write, execute for file owner, root): 
  - `sudo chmod 700 /data/.secret/njalla/keys-file.json`

And finally adding it to your nix configuration:

```nix
  nixarr.ddns.njalla = {
    enable = true;
    keysFile = "/data/.secret/njalla/keys-file.json";
  };
```

After rebuilding, you can check the output of the DDNS script:

```sh
  sudo systemctl status ddnsNjalla.service
```

Where you should see something like:

```
  Mar 03 21:05:00 pi systemd[1]: Starting Sets the Njalla DDNS records...
  Mar 03 21:05:02 pi ddns-njalla[26842]: {"status": 200, "message": "record updated", "value": {"A": "93.184.216.34"}}
  Mar 03 21:05:02 pi ddns-njalla[26845]: {"status": 200, "message": "record updated", "value": {"A": "93.184.216.34"}}
  Mar 03 21:05:02 pi systemd[1]: ddnsNjalla.service: Deactivated successfully.
  Mar 03 21:05:02 pi systemd[1]: Finished Sets the Njalla DDNS records.
  Mar 03 21:05:02 pi systemd[1]: ddnsNjalla.service: Consumed 560ms CPU time, received 11.7K IP traffic, sent 3.0K IP traffic.
```

Then run the following to get your public IP address:

```sh
  curl https://ipv4.icanhazip.com/ 
```

And if you check your njalla domain page, you should see your public IP on
your Dynamic DNS record! 

And after waiting a little you should be able to connect to your ip, using
the set domain.
