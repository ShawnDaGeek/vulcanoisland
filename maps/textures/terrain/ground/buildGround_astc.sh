#/bin/sh
CONVERTER=../../../../../../tools/textureConverter/textureConverter

if ! [ -z "$1" ]; then
QUALITY="-quality $1"
fi

$CONVERTER -colorspace srgb -verbose -channels 3 -arch astc $QUALITY -outfile ground_diffuse -skipIfCurrent -array 5 source/cultivator_diffuse.png source/acre_diffuse.png source/acre_fine_diffuse.png source/acre_plantedRows_diffuse.png source/acre_grassGrowth_diffuse.png
$CONVERTER -colorspace linear -verbose -channels 3 -arch astc $QUALITY -outfile ground_normal -skipIfCurrent -array 5 source/cultivator_normal.png source/acre_normal.png source/acre_fine_normal.png source/acre_plantedRows_normal.png source/acre_grassGrowth_normal.png

$CONVERTER -colorspace srgb -verbose -channels 3 -arch astc $QUALITY -outfile ground2_diffuse -skipIfCurrent -array 5 source/cultivator_diffuse.png source/acre_diffuse.png source/acre_fine_diffuse.png source/acre_plantedRows_diffuse.png source/acre_grassGrowth2_diffuse.png
$CONVERTER -colorspace linear -verbose -channels 3 -arch astc $QUALITY -outfile ground2_normal -skipIfCurrent -array 5 source/cultivator_normal.png source/acre_normal.png source/acre_fine_normal.png source/acre_plantedRows_normal.png source/acre_grassGrowth2_normal.png

$CONVERTER -colorspace srgb -verbose -channels 3 -arch astc $QUALITY -outfile groundLayer_diffuse -skipIfCurrent -array 4 source/ground_manure_diffuse.png source/ground_liquidManure_diffuse.png source/ground_lime_diffuse.png source/ground_straw_diffuse.png
$CONVERTER -colorspace linear -verbose -channels 3 -arch astc $QUALITY -outfile groundLayer_normal -skipIfCurrent -array 4 source/ground_manure_normal.png source/ground_liquidManure_normal.png source/ground_lime_normal.png source/ground_straw_normal.png
