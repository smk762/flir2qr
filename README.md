# flir2qr
A bash script using GDAL and OGR to create a digital map for use in Avenza Maps, QGIS, Google Earth and many other GIS software apps.

Designed to trigger via incron table entry when file upload detected, passing the incron [path] $@ and [file] $# as script parameters. Created for use in Ubuntu 16.04, though should run in any OS with bash / incron / GDAL.

#Install GDAL- http://www.gdal.org/index.html

`sudo add-apt-repository ppa:ubuntugis/ppa`

`sudo apt-get update`

`sudo apt update`

`sudo apt install gdal-bin -y`

`sudo apt install python-gdal -y`

#Install QRencode - https://fukuchi.org/works/qrencode/
`sudo apt install qrencode -y`

#Clone Flir2qr
`cd /`

`git clone https://github.com/smk762/flir2qr`

#Install incron - http://inotify.aiken.cz/?section=incron&page=doc
`sudo apt install incron -y`

#Setup incron 

edit allowed users - `nano /etc/incron.allow` 

add user `root`

edit incron table `sudo incrontab -e`

Add line - `/flir2qr/upload IN_CLOSE_WRITE /bin/bash /flir2qr/sh/flir2qr_v07.sh $@ $#`

(modify to full installation path)

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
