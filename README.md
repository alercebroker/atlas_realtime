## ATLAS real-time stream

This repository contains the files needed to create the data that is consumed by the [ATLAS-avro repo](https://github.com/alercebroker/atlas-avro), which creates the AVRO alerts that can be send to a Kafka cluster.

1) The script **img_groups.sh**, receives two arguments: a **telescope** (and camera) and a **night** in the ATLAS format.

* **Telescope:** a **telescope** in ATLAS is **01** for Mauna Loa and **02** for Haleakala, the **camera** used should be always **'a'** (although this may change in the future.) Therefore, the first argument of the script could be **01a** or **02a**.

* **Night:** a night is defined by a Modified Julian Day, e.g.: **58884**. There is more about this in the ATLAS Internal Site.

The output of this script is the file **\<telescope\>\<night\>_img.groups**. The file contains one line per each **tessellation** and the data iniside follows the pattern: **\<tessellation\> \<exposure1\> \<exposure2\> \<exposure3\> \<exposure4\>**, where the exposures are the ones corresponding to the tessellation and can be between 1 and 5 (usually 4).

E.g.:
```
SV341N74 02a58884o031o 02a58884o056o 02a58884o057o 02a58884o099o
SV342N75 02a58884o044o 02a58884o049o 02a58884o101o 02a58884o102o
```

2) The script **mkobjects.sh**, receives three arguments: a **tessellation** (e.g.: SV341N74), the  **\<telescope\>\<night\>_img.groups** file and the **tolerance** in arcseconds (should be 1.9 since the pixel size is 1.86").
