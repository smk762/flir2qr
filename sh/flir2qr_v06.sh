#!/bin/bash
RED='\033[1;0;31m';
WHITE='\033[1;37m';
BLUE='\033[1;34m';
FLIR2QR_PATH="$(dirname $1)";
timestamp=$(date +%F_%T);
if [ -e ${1}/${2} ];
  then echo -e "${BLUE}Uploaded file $1/$2 detected";
  else echo -e "${RED}$timestamp - $2 does not exist, exiting.${WHITE}"$'\r'; echo -e "$timestamp - $2 does not exist, exiting."$'\r' >> $FLIR2QR_PATH/log/error.log; exit 1; 
fi
GREEN='\033[0;32m';
YELLOW='\033[1;33m';
CYAN='\033[0;36m';
PURPLE='\033[1;35m';
RED='\033[1;0;31m';
IP="$(echo -e $(hostname -I) | tr -d '[:space:]')";
echo -e "${PURPLE}flir2qr path is $FLIR2QR_PATH";
ROADSFILE="$FLIR2QR_PATH/vectors/sample_roads_4m_buff.shp";
GRIDFILE="$FLIR2QR_PATH/vectors/100m_grid_wgs84_1m_buff.shp";
WILDFILE="${2%.*}";
MAPSIZE="2000 1600";
PIXELRANGE="0 8000";
LOGO="$FLIR2QR_PATH/img/logo.jpg";
LEGEND="$FLIR2QR_PATH/img/legend.jpg";
echo -e "Started processing $2 at $timestamp"$'\r' >> $FLIR2QR_PATH/log/flir2qr.log;
if [ -e ${FLIR2QR_PATH}/temp.txt ];
	then echo -e "${PURPLE}TempDir has already been spawned";
	else echo -e "$RANDOM" > "$FLIR2QR_PATH/temp.txt";
fi
TEMPDIR=$(cat $FLIR2QR_PATH/temp.txt);
TEMP_PATH=$FLIR2QR_PATH/$TEMPDIR;
echo -e "${PURPLE}Creating temporary folders in $TEMP_PATH";
declare -a PROCDIRS=('raw' 'mga_50' 'wgs84' 'clipfence' 'hotspot' 'basemap' 'roads' 'kmz' 'kml' 'shp' 'grid');
for dir in "${PROCDIRS[@]}"; do  mkdir -p $TEMP_PATH/$dir; done
echo -e "${PURPLE}IP address is $IP";
echo -e "${PURPLE}Processing $2 at $timestamp";
case "$2" in
*.kmz)
	echo -e "${PURPLE}Converting KMZ to SHP${YELLOW}";
	unzip $1/$2 -d $TEMP_PATH/kmz;
	ogr2ogr $TEMP_PATH/shp/$WILDFILE.shp $TEMP_PATH/kml/doc.kml -overwrite -a_srs EPSG:4326;
;;
*.tfw)
	echo -e "${PURPLE}Copying world file${YELLOW}";
	echo -e "${GREEN}Copying $2 ${YELLOW}";
	cp $1/$2 $TEMP_PATH/raw/$2;
;;
*.tif)
	i=0;
	while [[ ( -z $tfw ) && ( "$i" -lt "10" ) ]]
		do
		echo -e "${GREEN}Waiting for world file $WILDFILE.tfw";
    if [ -z $tfw ];
    	then tfw=$(ls $FLIR2QR_PATH/upload | grep $WILDFILE.tfw);	sleep 3;
    	else echo -e "${BLUE}World file $WILDFILE.tfw detected!";
    fi
		let "i++";
	done
	if [[ ("$i" -eq "10") ]]; then echo -e "${RED}$timestamp - $2 timed out waiting for world file $tfw ${WHITE}"$'\r'; echo -e "$timestamp - $2 timed out waiting for world file $tfw"$'\r' >> $FLIR2QR_PATH/log/error.log; exit 1;
  fi
  cp $1/$tfw $TEMP_PATH/raw/$tfw;
	echo -e "${GREEN}World file $tfw detected"; 
	echo -e "${PURPLE}Processing IR Rasters${YELLOW}";
	echo -e "${GREEN}Copying IR tif${YELLOW}";
	cp $1/$2 $TEMP_PATH/raw/$WILDFILE.tif;
	echo -e "${GREEN}Stamping IR tif CRS${YELLOW}";
	gdal_translate -a_srs EPSG:28350 $TEMP_PATH/raw/$WILDFILE.tif $TEMP_PATH/mga_50/${WILDFILE}_mga_50.tif -co COMPRESS=LZW -a_nodata 0 -outsize $MAPSIZE;
	echo -e "${GREEN}Convert IR raster wgs84${YELLOW}";
	gdalwarp -s_srs EPSG:28350 -t_srs EPSG:4326 $TEMP_PATH/mga_50/${WILDFILE}_mga_50.tif $TEMP_PATH/wgs84/${WILDFILE}_wgs84.tif -co COMPRESS=LZW -overwrite -ts $MAPSIZE;
	echo -e "${GREEN}Scaling IR tif $TEMP_PATH/basemap/${WILDFILE}_wgs84_sc.tif ${YELLOW}";
	gdal_translate -a_srs EPSG:4326 $TEMP_PATH/wgs84/${WILDFILE}_wgs84.tif $TEMP_PATH/basemap/${WILDFILE}_wgs84_sc.tif -b 1 -b 1 -b 1 -co COMPRESS=LZW -scale $PIXELRANGE 0 255 -stats -ot Byte -outsize $MAPSIZE;
 
	echo -e "${PURPLE}Creating clip fence${YELLOW}";
	echo -e "${GREEN}Reducing IR raster colours to make clip fence${YELLOW}";
	gdal_merge.py -co NBITS=1 -o $TEMP_PATH/clipfence/${WILDFILE}_extent.tif $TEMP_PATH/basemap/${WILDFILE}_wgs84_sc.tif;
	echo -e "${GREEN}Polygonising IR clip fence $TEMP_PATH/clipfence/${WILDFILE}_extent.tif ${YELLOW}";
	gdal_polygonize.py $TEMP_PATH/clipfence/${WILDFILE}_extent.tif $TEMP_PATH/clipfence/${WILDFILE}_extent.shp clip;
	echo -e "${GREEN}Stamping IR clip fence $TEMP_PATH/clipfence/${WILDFILE}_extent_wgs84.shp ${YELLOW}";
	ogr2ogr $TEMP_PATH/clipfence/${WILDFILE}_extent_wgs84.shp $TEMP_PATH/clipfence/${WILDFILE}_extent.shp -overwrite -a_srs EPSG:4326;
  echo -e "${GREEN}Dissolving IR clip fence $TEMP_PATH/clipfence/${WILDFILE}_fence_wgs84.shp${YELLOW}";
	ogr2ogr $TEMP_PATH/clipfence/${WILDFILE}_fence_wgs84.shp $TEMP_PATH/clipfence/${WILDFILE}_extent_wgs84.shp -dialect sqlite -sql "SELECT ST_Union(geometry) FROM '${WILDFILE}_extent_wgs84'";
 
 	echo -e "${PURPLE}Waiting for hotspot KML ${YELLOW}";
	hs=$(ls $TEMP_PATH/kml | grep kml);
	i=0;
	while [[ ( -z $hs ) && ( "$i" -lt "10" ) ]]
	do
		echo -e "${GREEN}Waiting for hotspot kml file";
    if [ -z $hs ];
    	then hs=$(ls $FLIR2QR_PATH/upload | grep kml); sleep 3;
    	else echo -e "${BLUE}Hotspot $WILDFILE.kml detected!";
    fi
		let "i++";		
	done
	if [[ "$i" -eq "10" ]]; then echo -e "${RED}$timestamp - $2 Timed out waiting for KML ${WHITE}"$'\r'; echo "$timestamp - $2 Timed out waiting for KML"$'\r' >> $FLIR2QR_PATH/log/error.log; exit 1; 
  fi
  cp $1/$hs $TEMP_PATH/kml/$hs;
	echo -e "${GREEN}Converting hotspot KML to SHP ${YELLOW}";
	ogr2ogr $TEMP_PATH/shp/${WILDFILE}_hs.shp $TEMP_PATH/kml/$hs -overwrite -a_srs EPSG:4326;
 
  echo -e "${PURPLE}Clipping vectors to IR fence${YELLOW}";
  echo -e "${GREEN}Clipping grid ${YELLOW}";
  ogr2ogr -clipsrc $TEMP_PATH/clipfence/${WILDFILE}_fence_wgs84.shp -clipsrclayer ${WILDFILE}_fence_wgs84 $TEMP_PATH/grid/${WILDFILE}_grid.shp $GRIDFILE; 
  echo -e "${GREEN}Clipping hotspots ${YELLOW}";
  ogr2ogr -clipsrc $TEMP_PATH/clipfence/${WILDFILE}_fence_wgs84.shp -clipsrclayer ${WILDFILE}_fence_wgs84 $TEMP_PATH/hotspot/${WILDFILE}_hs_clip.shp $TEMP_PATH/shp/${WILDFILE}_hs.shp; 
	echo -e "${GREEN}Clipping roads ${YELLOW}";
	ogr2ogr -clipsrc $TEMP_PATH/clipfence/${WILDFILE}_fence_wgs84.shp -clipsrclayer ${WILDFILE}_fence_wgs84 $FLIR2QR_PATH/$TEMPDIR/roads/${WILDFILE}_roads.shp $ROADSFILE -a_srs EPSG:4326 -progress;
   
	echo -e "${PURPLE}Burning vectors to raster"; 
 
  echo -e "${GREEN}Burning grid $TEMP_PATH/grid/${WILDFILE}_hs.tif ${YELLOW} ${YELLOW}";
	gdal_rasterize -burn 10 -burn 250 -burn 250 -ts $MAPSIZE $TEMP_PATH/grid/${WILDFILE}_grid.shp $TEMP_PATH/grid/${WILDFILE}_grid.tif -co COMPRESS=LZW -co PHOTOMETRIC=RGB -init 0 -a_nodata 0 -ot Byte -a_srs EPSG:4326;
  echo -e "${GREEN}Burning hotspots $TEMP_PATH/hotspot/${WILDFILE}_hs.tif ${YELLOW} ${YELLOW}";
	gdal_rasterize -burn 255 -burn 10 -burn 255 -ts $MAPSIZE $TEMP_PATH/hotspot/${WILDFILE}_hs_clip.shp $TEMP_PATH/hotspot/${WILDFILE}_hs.tif -co COMPRESS=LZW -co PHOTOMETRIC=RGB -init 0 -a_nodata 0 -ot Byte -a_srs EPSG:4326;
  echo -e "${GREEN}Burning roads $TEMP_PATH/roads/${WILDFILE}_roads_rgb.tif${YELLOW}";
	gdal_rasterize -burn 200 -burn 10 -burn 10 -ts $MAPSIZE $TEMP_PATH/roads/${WILDFILE}_roads.shp $TEMP_PATH/roads/${WILDFILE}_roads_rgb.tif -co COMPRESS=LZW -co PHOTOMETRIC=RGB -init 0 -a_nodata 0 -ot Byte -a_srs EPSG:4326;
 
	echo -e "${PURPLE}Merging rasters into final map $FLIR2QR_PATH/output/${WILDFILE}_basemap_wgs84.tif ${YELLOW}";
	gdal_merge.py -o $FLIR2QR_PATH/output/${WILDFILE}_basemap_wgs84.tif $TEMP_PATH/basemap/${WILDFILE}_wgs84_sc.tif $TEMP_PATH/roads/${WILDFILE}_roads_rgb.tif $TEMP_PATH/hotspot/${WILDFILE}_hs.tif $TEMP_PATH/grid/${WILDFILE}_grid.tif -n 0 -co COMPRESS=LZW -co INTERLEAVE=BAND -co PHOTOMETRIC=RGB -v -a_nodata 0 -init 0 -ot Byte;
 
	echo -e "${PURPLE}Adding $FLIR2QR_PATH/output/${WILDFILE}_basemap_wgs84.tif to /var/www/html/hotspotmaps/ ${YELLOW}"; 
	cp $FLIR2QR_PATH/output/${WILDFILE}_basemap_wgs84.tif /var/www/html/hotspotmaps/$WILDFILE.tif;
 
  echo -e "${PURPLE}Creating GeoPDF${YELLOW}"; 
  gdal_translate $FLIR2QR_PATH/output/${WILDFILE}_basemap_wgs84.tif $FLIR2QR_PATH/output/${WILDFILE}.pdf -of PDF -a_srs EPSG:4326 -co EXTRA_IMAGES=$LOGO,0,0,1,$LEGEND,5,45,1 -outsize $MAPSIZE;
	cp $FLIR2QR_PATH/output/${WILDFILE}.pdf /var/www/html/hotspotmaps/$WILDFILE.pdf;
 
  echo -e "${PURPLE}Creating KML${YELLOW}";
  gdal2tiles.py -k -t $2 $FLIR2QR_PATH/output/${WILDFILE}_basemap_wgs84.tif /var/www/html/hotspotmaps/${WILDFILE}.kml;
  
	echo -e "${PURPLE}generating QR code for http://$IP/hotspotmaps/$WILDFILE.tif ${YELLOW}";
	qrencode -o /var/www/html/hotspotmaps/qr/$WILDFILE.tif.png http://$IP/hotspotmaps/$WILDFILE.tif;
  qrencode -o /var/www/html/hotspotmaps/qr/$WILDFILE.pdf.png http://$IP/hotspotmaps/$WILDFILE.pdf;
  qrencode -o /var/www/html/hotspotmaps/qr/$WILDFILE.kml.png http://$IP/hotspotmaps/$WILDFILE.kml/${WILDFILE}_basemap.kml;
  
  cp /var/www/html/hotspotmaps/qr/$WILDFILE.pdf.png $FLIR2QR_PATH/output/${WILDFILE}_qr.png;
  cp $FLIR2QR_PATH/kml/template.kml $FLIR2QR_PATH/output/${WILDFILE}_qr.kml;
    
  centroid=$(echo $(gdalinfo $TEMP_PATH/clipfence/${WILDFILE}_extent.tif | grep Center |  grep -o '(.*).' | sed 's/[()]//g'));
  echo -e "${PURPLE}Creating $WILDFILE centroid placemark at $centroid ${YELLOW}";
  
  sed -i 's/WILDFILE/'"$WILDFILE"'_qr.png/g' "$FLIR2QR_PATH"'/output/'"$WILDFILE"'_qr.kml';
  sed -i 's/CENTROID/'"$centroid"'/g' "$FLIR2QR_PATH"'/output/'"$WILDFILE"'_qr.kml';
  mv /var/www/html/hotspotmaps/$WILDFILE.kml/doc.kml /var/www/html/hotspotmaps/$WILDFILE.kml/${WILDFILE}_basemap.kml;
  mv $FLIR2QR_PATH/output/${WILDFILE}_qr.kml /var/www/html/hotspotmaps/$WILDFILE.kml/${WILDFILE}_qr.kml;
  mv $FLIR2QR_PATH/output/${WILDFILE}_qr.png /var/www/html/hotspotmaps/$WILDFILE.kml/${WILDFILE}_qr.png;
 ;;
*.kml)
	echo -e "${PURPLE}Converting hotspots KML to SHP ${YELLOW}";
	cp $1/$2 $TEMP_PATH/kml/$2;
	ogr2ogr $TEMP_PATH/shp/$WILDFILE.shp $TEMP_PATH/kml/$2 -overwrite -a_srs EPSG:4326;
;;
*)
  echo -e "${RED}Unexpected file type '$2'. TIF/TFW or KML/KMZ only! ${WHITE}";
  echo "$timestamp - bad filetype uploaded - $2"$'\r' >> ${FLIR2QR_PATH}/log/error.log;
;;
esac
echo -e "$2 successfully processed!"$'\r' >> $FLIR2QR_PATH/log/flir2qr.log;
echo -e "${BLUE}Processing $2 complete! ${WHITE}";
sudo cp $FLIR2QR_PATH/log/* /var/www/html/hotspotmaps/log;
