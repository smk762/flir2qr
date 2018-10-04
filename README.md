![flir2qr concept diagram](https://github.com/smk762/flir2qr/raw/master/img/concept.jpg)

# flir2qr
A bash script using GDAL and OGR to create a digital map for use in Avenza Maps, QGIS, Google Earth and many other GIS software apps.

Designed to trigger via incron table entry when file upload detected, passing the incron [path] $@ and [file] $# as script parameters. Created for use in Ubuntu 16.04, though should run in any OS with bash / incron / GDAL.

## AS SUPERUSER

## Install GDAL- http://www.gdal.org/index.html (Use the repo below)

`sudo add-apt-repository ppa:ubuntugis/ubuntugis-unstable` // GDAL 2.2.2

`sudo apt update`

`sudo apt install gdal-bin gdal-data libgdal-dev libgdal20 python-gdal spatialite-bin -y`

## Install zip, p7zip, QRencode - https://fukuchi.org/works/qrencode/, incron - http://inotify.aiken.cz/?section=incron&page=doc
`sudo apt install p7zip-full qrencode incron -y`

## Setup incron 
edit allowed users - `sudo nano /etc/incron.allow` 

add user `f2quser`

## Get latest version of gdal_edit.py

`cd ~`

`curl https://raw.githubusercontent.com/OSGeo/gdal/master/gdal/swig/python/scripts/gdal_edit.py > /home/<user>/gdal_edit.py`

`sudo mv gdal_edit.py /usr/bin/gdal_edit.py`

`sudo chmod 775 /usr/bin/gdal_edit.py`

## Clone Flir2qr
`cd /opt/`

`sudo git clone https://github.com/smk762/flir2qr`

## Create user/group and set permissions 
`sudo adduser f2quser`

`sudo passwd f2quser`  // set a password

`sudo addgroup f2qgroup`

`sudo chown f2quser:f2qgroup /opt/flir2qr -R`

`sudo chown f2quser:f2qgroup /var/www/html/flir2qr -R`

`sudo chmod 775 /opt/flir2qr -R`

`sudo chmod 775 /var/www/html/flir2qr -R`

`su f2quser` // switch to fq2user

`incrontab -e`   // edit incron table for f2quser

Add line - `/mnt/data/dmp IN_CLOSE_WRITE /bin/bash /opt/flir2qr/sh/flir2qr_v09 $@ $#`


## Install imagemagick (for dynamic coordinate text in PDFs)

`sudo apt-get install imagemagick`

### To do
add coordinates to PDF output
update legend and logos

----------------------------------------------------------------------------------------------------------------------
#notes below pending review - code modification to different file formats in progress

#Required local vector datasets -Roads shapefile -Grid shapefile

#Output

    KML superoverlay
    GeoPDF
    GeoTiff

#Usage - incrontab

`/flir2qr/upload IN_CLOSE_WRITE /bin/bash /flir2qr/sh/flir2qr_v04.sh $@ $#`

#Usage - terminal

`./flir2qr [path] [file]`

`[path]` is folder containing input data.

`[file]` is file to be processed.

#Process

FLIR *.tif imagery and a *.kmz of polygonised hotspot areas is delivered to the designated folder on the server. incron intitiates flir2qr to run on each file as soon as it's finished being written to.

flir2qr extracts kml from hotspot kmz, then converts into a raster.

TIF/TFW file pairs are used to define the imagery's coordinate system (georeferencing).

TIF is deprojected to EPSG:4326, and single band u16 greyscale pixel values remaped and scaled to RGB bands.

TIF extent polygon is created to clip and rasterize local vector data (roads and grid).

All rasters merged in following order (base to foreground)

    FLIR imagery
    roads
    hotspots
    grid

Output of merged rasters converted to KML + geoTIF + geoPDF and moved to `/var/www/html/[output folder]`

QR codes for hyperlink to each output file type generated

QR codes embedded into a new KML placemark at centroid of each FLIR image, and (pending) sent to subscribers.
