#! /bin/bash
#----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# Sebastiano Poggi wrote this file.  As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.   Seb
# ----------------------------------------------------------------------------

# Inspired by http://www.spaziocurvo.com/2015/03/svg-to-icns-script-for-mac-os-x/
# and https://gist.github.com/plroebuck/af19a26c908838c7f9e363c571199deb

usage() {
    cat <<END_USAGE >&2
Usage: ${script} <svg file>
  svg file: input SVG file

END_USAGE
}

argc="$#"
if [[ "$argc" -lt 1 ]] || [[ "$argc" -gt 2 ]];
then
    usage
    exit 1
fi

# Check the input exists and is an SVG file
svgFilename="$1"

name=${svgFilename%.*}
ext=${svgFilename##*.}

if [ ! -f "${svgFilename}" ];
then
    usage
    echo "File not found: ${svgFilename}" >&2
    exit 2

    $(file "${svgFilename}" | cut -d':' -f2- | grep -qs 'SVG')
    if [ "$?" -ne 0 ];
    then
        usage
        echo "Not a valid SVG file: ${svgFilename}" >&2
        exit 3
    fi
fi

echo "Creating icns file from: $name"

outDirName="$name".iconset

if [[ -e "${outDirName}" ]]; then
    echo "Deleting existing temp folder $outDirName"
    rm -rf "$outDirName"
fi
mkdir "$outDirName"

fullSizeImage="$outDirName/$name.png"

# Use QuickLook Manager to create a full size PNG from the SVG
qlmanage -t -s 1024 -o "$outDirName" "$svgFilename" > /dev/null

if [ "$?" -ne 0 ];
then
    echo "Error rasterizing the SVG file" >&2
    exit 4
fi

mv "$outDirName/$svgFilename.png" "$fullSizeImage"

# Then use Scriptable Image Processing system to create the various sizes
sips -z 16 16 "$fullSizeImage" --out "$outDirName/icon_16x16.png" > /dev/null
sips -z 32 32 "$fullSizeImage" --out "$outDirName/icon_16x16@2x.png" > /dev/null
cp "$outDirName/icon_16x16@2x.png" "$outDirName/icon_32x32.png" > /dev/null
sips -z 64 64 "$fullSizeImage" --out "$outDirName/icon_32x32@2x.png" > /dev/null
sips -z 128 128 "$fullSizeImage" --out "$outDirName/icon_128x128.png" > /dev/null
sips -z 256 256 "$fullSizeImage" --out "$outDirName/icon_128x128@2x.png" > /dev/null
cp "$outDirName/icon_128x128@2x.png" "$outDirName/icon_256x256.png" > /dev/null
sips -z 512 512 "$fullSizeImage" --out "$outDirName/icon_256x256@2x.png" > /dev/null
cp "$outDirName/icon_256x256@2x.png" "$outDirName/icon_512x512.png" > /dev/null
sips -z 1024 1024 "$fullSizeImage" --out "$outDirName/icon_512x512@2x.png" > /dev/null

rm "$fullSizeImage" > /dev/null

# Combine the various PNG files into an ICNS file
iconutil -c icns "$outDirName" > /dev/null

if [ "$?" -ne 0 ];
then
    echo "Error converting iconset to ICNS" >&2
    exit 5
else
    #rm -rf "${outDirName}" > /dev/null
    echo "All done! Your new icns file is $name.icns"
fi
